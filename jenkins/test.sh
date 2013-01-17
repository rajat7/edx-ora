#! /bin/bash

set -e
set -x

function github_status {
    gcli status create mitx mitx $GIT_COMMIT \
         --params=$1 \
                  target_url:$BUILD_URL \
                  description:"Build #$BUILD_NUMBER $2" \
         -f csv
}

function github_mark_failed_on_exit {
    trap '[ $? == "0" ] || github_status state:failure "failed"' EXIT
}

git remote prune origin

github_mark_failed_on_exit
github_status state:pending "is running"

# Reset the submodule, in case it changed
git submodule foreach 'git reset --hard HEAD'

# Set the IO encoding to UTF-8 so that askbot will start
export PYTHONIOENCODING=UTF-8

GIT_BRANCH=${GIT_BRANCH/HEAD/master}

if [ ! -d /mnt/virtualenvs/"$JOB_NAME" ]; then
    mkdir -p /mnt/virtualenvs/"$JOB_NAME"
    virtualenv /mnt/virtualenvs/"$JOB_NAME"
fi

source /mnt/virtualenvs/"$JOB_NAME"/bin/activate
pip install -q -r pre-requirements.txt
pip install -q -r test-requirements.txt
yes w | pip install -q -r requirements.txt

rake clobber
TESTS_FAILED=0
# Don't run the studio tests until feature/cale/cms-master is merged in
# rake test_cms[false] || TESTS_FAILED=1
rake test_lms[false] || TESTS_FAILED=1
rake test_common/lib/capa || TESTS_FAILED=1
rake test_common/lib/xmodule || TESTS_FAILED=1
# Don't run the studio tests until feature/cale/cms-master is merged in
# rake phantomjs_jasmine_cms || true
rake coverage:xml coverage:html

[ $TESTS_FAILED == '0' ]
rake autodeploy_properties

github_status state:success "passed"