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

set -euo pipefail

if [[ -n "${KOKORO_ROOT:-}" ]]; then
  readonly TINK_BASE_DIR="$(echo "${KOKORO_ARTIFACTS_DIR}"/git*)"
  cd "${TINK_BASE_DIR}/tink_go_awskms_v2"
fi

# Sourcing required to update callers environment.
source ./kokoro/testutils/install_go.sh
echo "Using go binary from $(which go): $(go version)"

# TODO(b/238389921): Run check_go_generated_files_up_to_date.sh after a
# refactoring that takes into account extensions to tink-go.
./kokoro/testutils/copy_credentials.sh "testdata" "aws"

MANUAL_TARGETS=()
# Run manual tests that rely on test data only available via Bazel.
if [[ -n "${KOKORO_ROOT:-}" ]]; then
  MANUAL_TARGETS+=( "//integration/awskms:awskms_test" )
fi
readonly MANUAL_TARGETS

./kokoro/testutils/run_bazel_tests.sh -t --test_arg=--test.v . \
  "${MANUAL_TARGETS[@]}"
