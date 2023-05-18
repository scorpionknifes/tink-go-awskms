#!/bin/bash
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

# By default when run locally this script runs the command below directly on the
# host. The CONTAINER_IMAGE variable can be set to run on a custom container
# image for local testing. E.g.:
#
# CONTAINER_IMAGE="gcr.io/tink-test-infrastructure/linux-tink-go-base:latest" \
#  sh ./kokoro/gcp_ubuntu/bazel/run_tests.sh
#
# The user may specify TINK_BASE_DIR as the folder where to look for
# tink-go-awskms and its dependencies. That is:
#   ${TINK_BASE_DIR}/tink_go
#   ${TINK_BASE_DIR}/tink_go_awskms
# NOTE: tink_go is fetched from GitHub if not found.
set -euo pipefail

RUN_COMMAND_ARGS=()
if [[ -n "${KOKORO_ARTIFACTS_DIR:-}" ]]; then
  TINK_BASE_DIR="$(echo "${KOKORO_ARTIFACTS_DIR}"/git*)"
  readonly C_PREFIX="us-docker.pkg.dev/tink-test-infrastructure/tink-ci-images"
  readonly C_NAME="linux-tink-go-base"
  readonly C_HASH="2fddb51977a951759ab3b87643b672d590f277fe6ade5787fa8721dd91ea839a"
  CONTAINER_IMAGE="${C_PREFIX}/${C_NAME}@sha256:${C_HASH}"
  RUN_COMMAND_ARGS+=( -k "${TINK_GCR_SERVICE_KEY}" )
fi
: "${TINK_BASE_DIR:=$(cd .. && pwd)}"
readonly TINK_BASE_DIR
readonly CONTAINER_IMAGE

# If running from the tink_go_awskms folder this has no effect.
cd "${TINK_BASE_DIR}/tink_go_awskms"

if [[ -n "${CONTAINER_IMAGE:-}" ]]; then
  RUN_COMMAND_ARGS+=( -c "${CONTAINER_IMAGE}" )
fi

# Check for dependencies in TINK_BASE_DIR. Any that aren't present will be
# downloaded.
readonly GITHUB_ORG="https://github.com/tink-crypto"
./kokoro/testutils/fetch_git_repo_if_not_present.sh "${TINK_BASE_DIR}" \
  "${GITHUB_ORG}/tink-go"

# TODO(b/238389921): Run check_go_generated_files_up_to_date.sh after a
# refactoring that takes into account extensions to tink-go.
./kokoro/testutils/copy_credentials.sh "testdata" "aws"

cp WORKSPACE WORKSPACE.bak

# Replace com_github_tink_crypto_tink_go with a local one.
grep -r "com_github_tink_crypto_tink_go" -l --include="*.bazel" \
  | xargs sed -i \
      "s~com_github_tink_crypto_tink_go~com_github_tink_crypto_tink_go_local~g"

sed -i 's~workspace(name = "tink_go_awskms")~workspace(name = "tink_go_awskms")\
\
local_repository(\
    name = "com_github_tink_crypto_tink_go_local",\
    path = "../tink_go",\
)~' WORKSPACE

MANUAL_TARGETS=()
# Run manual tests that rely on test data only available via Bazel.
if [[ -n "${KOKORO_ROOT:-}" ]]; then
  MANUAL_TARGETS+=( "//integration/awskms:awskms_test" )
fi
readonly MANUAL_TARGETS

./kokoro/testutils/run_command.sh "${RUN_COMMAND_ARGS[@]}" \
  ./kokoro/testutils/run_bazel_tests.sh . "${MANUAL_TARGETS[@]}"

mv WORKSPACE.bak WORKSPACE
