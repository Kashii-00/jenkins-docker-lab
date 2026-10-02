stage('Deploy to ECS') {
    environment {
        ECS_CLUSTER = 'devsecops-cluster'
        ECS_SERVICE = 'devsecops-app-service-z88n5o03'
        ECS_CONTAINER = 'devsecops-web'
    }

    steps {
        timeout(time: 15, unit: 'MINUTES') {
            sh '''#!/bin/bash
set -euo pipefail
export AWS_PAGER=""
umask 077

IMAGE_URI="$(cat image-uri.txt)"
test "$IMAGE_URI" = "${ECR_REGISTRY}/${ECR_REPOSITORY}:${BUILD_NUMBER}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

describe_service() {
    aws ecs describe-services --region "$AWS_REGION" \
      --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" \
      --output json
}

describe_service > "$WORK_DIR/before.json"

jq -e '
  (.failures | length) == 0 and (.services | length) == 1 and
  (.services[0] | .status == "ACTIVE" and .desiredCount > 0 and
    .runningCount == .desiredCount and
    (.deployments | length) == 1 and
    .deployments[0].rolloutState == "COMPLETED")
' "$WORK_DIR/before.json" > /dev/null

OLD_TASK_DEF="$(jq -er '.services[0].taskDefinition' "$WORK_DIR/before.json")"

aws ecs describe-task-definition --region "$AWS_REGION" \
  --task-definition "$OLD_TASK_DEF" --query taskDefinition \
  --output json > "$WORK_DIR/current.json"

jq -e --arg container "$ECS_CONTAINER" '
  .family == "devsecops-app" and
  ([.containerDefinitions[] | select(.name == $container)] | length) == 1
' "$WORK_DIR/current.json" > /dev/null

jq --arg image "$IMAGE_URI" --arg container "$ECS_CONTAINER" '
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
      .compatibilities, .registeredAt, .registeredBy, .deregisteredAt)
  | (.containerDefinitions[] | select(.name == $container) | .image) = $image
' "$WORK_DIR/current.json" > "$WORK_DIR/new.json"

NEW_TASK_DEF="$(aws ecs register-task-definition --region "$AWS_REGION" \
  --cli-input-json "file://$WORK_DIR/new.json" \
  --query taskDefinition.taskDefinitionArn --output text)"

test -n "$NEW_TASK_DEF" && test "$NEW_TASK_DEF" != "None"
echo "Deploying $IMAGE_URI using $NEW_TASK_DEF"

aws ecs update-service --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" \
  --task-definition "$NEW_TASK_DEF" > /dev/null

if ! aws ecs wait services-stable --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE"; then
    describe_service | jq '{failures, services: [.services[] |
      {taskDefinition, deployments, events: .events[:5]}]}'
    echo 'Deployment did not stabilize within the wait period.' >&2
    exit 1
fi

describe_service > "$WORK_DIR/after.json"

if ! jq -e --arg expected "$NEW_TASK_DEF" '
  (.failures | length) == 0 and (.services | length) == 1 and
  (.services[0] | .taskDefinition == $expected and .desiredCount > 0 and
    .runningCount == .desiredCount and .pendingCount == 0 and
    (.deployments | length) == 1 and
    .deployments[0].taskDefinition == $expected and
    .deployments[0].rolloutState == "COMPLETED")
' "$WORK_DIR/after.json" > /dev/null; then
    echo 'The requested revision is not successfully deployed; check for rollback.' >&2
    exit 1
fi

jq -n --arg image "$IMAGE_URI" --arg previous "$OLD_TASK_DEF" \
  --arg deployed "$NEW_TASK_DEF" \
  '{image: $image, previousTaskDefinition: $previous, deployedTaskDefinition: $deployed}' \
  > deployment-summary.json

echo "Deployment verified: $NEW_TASK_DEF"
'''
        }

        archiveArtifacts artifacts: 'deployment-summary.json', fingerprint: true
    }
}