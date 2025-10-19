#!/bin/bash

YELLOW="\e[0;33m"
RESET="\e[0m"

if [ ! -f ./scripts/run_tests.sh ]
then
	echo "Error: ./scripts/run_tests.sh not found"
	exit 1
fi
if [ ! -f pyproject.toml ]
then
	echo "Error: pyproject.toml not found"
	exit 1
fi

if ! git diff-index --quiet --cached HEAD --
then
	echo "Error: dirty git working tree"
	exit 1
fi

if [ "$(git rev-parse --abbrev-ref HEAD)" != "master" ]
then
	echo "Error: can only release from master branch"
	exit 1
fi

echo "This script will create a git tag, git commit and a pypi release"
echo "Do you really want to run that? [y/N]"
read -r -n1 yn
if ! [[ "$yn" =~ [yY] ]]
then
	echo "aborting ..."
	exit 0
fi

if [ ! -f .env ]
then
	(
		echo "# get it from https://pypi.org/manage/account/token/"
		echo 'PYPI_TOKEN='
	) > .env
fi
if ! pypi_token="$(grep PYPI_TOKEN= .env | cut -d'=' -f2-)"
then
	echo "Error: failed to load env file"
	exit 1
fi
if [ "$pypi_token" == "" ]
then
	echo "Error: pypi token unset check your .env file"
	exit 1
fi

if [ ! -x "$(command -v twine)" ]
then
	echo "Error: command twine not found. Make sure to run:"
	echo ""
	echo "       pip install twine build"
	echo ""
	exit 1
fi

function commits_since_last_tag() {
	git log "$(git describe --tags --abbrev=0)..HEAD" --pretty=format:'%s'
}

function list_api_breaking_commits() {
	printf '%b' "$YELLOW"
	if commits_since_last_tag | grep -F '!: '
	then
		printf '%b' "$RESET"
		return 0
	fi
	printf '%b' "$RESET"
	return 1
}

if ! latest_tag="$(git tag | sort -V | tail -n1)"
then
	echo "Error: failed to get latest tag"
	exit 1
fi
echo ""
echo ""
echo ""
echo "==================================================================="
echo "current tag names:"
git tag | sort -V | awk '{ print "  " $0 }'
echo "==================================================================="
echo "How to pick a tag name?"
echo " - change lib user facing api -> at least minor version bump"
echo " - adding a feature or a new api -> does NOT require a minor bump"
echo " - change internal (local variables etc) api -> patch version bump"
echo " - drastic user affecting change -> major version bump"
echo "Only a patch version change should NEVER break a users code"
echo "==================================================================="

echo ""

if list_api_breaking_commits
then
	echo ""
	echo "=!= Found api breaking commits! See list above ^^^              =!="
	echo "=!= Do at least a minor version jump due to breaking changes    =!="
	echo "=!= https://www.conventionalcommits.org/en/v1.0.0/              =!="
	echo "==================================================================="
fi

read -r -p "tag name: " -i "$latest_tag" -e tag_name
if [ "$tag_name" == "" ]
then
	echo "Error: tag name can not be empty"
	exit 1
fi
if [ "$tag_name" == "$latest_tag" ]
then
	echo "Error: please use a new tag version"
	exit 1
fi
if [ "$(git tag -l "$tag_name")" != "" ]
then
	echo "Error: tag already exists"
	exit 1
fi
if [ "${tag_name::1}" != "v" ]
then
	echo "Error: tag has to start with a v"
	exit 1
fi
if [[ "$tag_name" =~ ^v([0-9]+)\.[0-9]+\.[0-9]+$ ]]
then
	major="${BASH_REMATCH[1]}"
	if [[ "$latest_tag" =~ ^v([0-9]+)\.[0-9]+\.[0-9]+$ ]]
	then
		latest_major="${BASH_REMATCH[1]}"
		diff="$((major - latest_major))"
		if [[ "$diff" -gt "1" ]]
		then
			echo "Error: new major version is $diff bigger than current"
			echo "       can only jump 1 major version at a time max"
			echo "       $latest_tag -> $tag_name"
			exit 1
		elif [[ "$diff" -lt "0" ]]
		then
			echo "Error: new major version is $diff smaller than current"
			echo "       can only increase or stay equal"
			echo "       $latest_tag -> $tag_name"
			exit 1
		fi
		if [ "$diff" == "1" ]
		then
			warn_todos
		fi
	else
		echo "Error: failed to parse latest tag"
		latest_tag=v0.0.0
		# exit 1
	fi
else
	echo "Error: tag has to match vMAJOR.MINOR.PATCH format"
	exit 1
fi
if [[ "$( (git tag;echo "$tag_name") | sort -V | tail -n1)" != "$tag_name" ]]
then
	echo "Error: the tag name you entered '$tag_name' does not seem to be the latest"
	echo "       instead '$( (git tag;echo v0.0.2) | sort -V | tail -n1)' is the latest"
	echo "       ensure a new release has the latest semantic version"
	exit 1
fi

if ! commit="$(git log -n 1 --pretty=format:"%h %s")"
then
	echo "Error: failed to get commit"
	exit 1
fi

echo "====================================================="
echo "commit: $commit"
echo "tag: $tag_name             (superseding: $latest_tag)"
echo "====================================================="
echo "Is that info correct? [y/N]"
read -r -n1 yn
if ! [[ "$yn" =~ [yY] ]]
then
	echo "aborting ..."
	exit 0
fi

if ! ./scripts/run_tests.sh
then
	echo "Error: tests failed aborting ..."
	exit 1
fi

# Do not update setup.cfg
# if the build fails anyways
if ! python -m build
then
	echo "Error: build failed"
	exit 1
fi

echo "[*] updating version in setup.cfg ..."
# can safely be ran multiple times
sed -i "s/^__version__ =.*/__version__ = '${tag_name:1}'/" ddnet_maploader/__version__.py

echo "[*] wiping old dist ..."
[[ -d dist ]] && rm -rf dist

# Try build again after setup.cfg update
if ! python -m build
then
	echo "Error: build failed"
	exit 1
fi

if [ ! -f dist/ddnet_maploader-"${tag_name:1}".tar.gz ]
then
	echo "Error: build did not generate expected file"
	echo "       dist/ddnet_maploader-${tag_name:1}.tar.gz"
	exit 1
fi

if ! pip install dist/ddnet_maploader-"${tag_name:1}".tar.gz
then
	echo "Error: local test install of package failed"
	exit 1
fi
if ! python -c "import ddnet_maploader"
then
	echo "Error: local test import failed"
	exit 1
fi

rm -rf /tmp/ddnet_maploader_test
mkdir -p /tmp/ddnet_maploader_test
cp -r tests /tmp/ddnet_maploader_test || exit 1
cp dist/ddnet_maploader-"${tag_name:1}".tar.gz /tmp/ddnet_maploader_test/
(
	deactivate &>/dev/null
	cd /tmp/ddnet_maploader_test || exit 1
	python -m venv venv
	# shellcheck disable=SC1091
	source venv/bin/activate
	if ! pip install ddnet_maploader-"${tag_name:1}".tar.gz
	then
		echo "Error: local test install of package failed (venv)"
		exit 1
	fi
	if ! python -c "import ddnet_maploader"
	then
		echo "Error: local test import failed (venv)"
		exit 1
	fi
	if ! python -c "from ddnet_maploader import load_map"
	then
		echo "Error: local test from ddnet_maploader import load_map failed (venv)"
		exit 1
	fi

	pip install pytest
	python -m pytest tests || exit 1
) || {
	echo "[*] venv install tests failed.";
	exit 1;
}

echo "[*] venv tests passed."

if ! git add ddnet_maploader/__version__.py
then
	echo "Error: git add ddnet_maploader/__version__.py failed"
	exit 1
fi

if [ "$(git diff HEAD --name-only)" != 'ddnet_maploader/__version__.py' ]
then
	echo "Error: unexpected files would be included in the commit"
	git diff HEAD  --name-only | grep -v '^ddnet_maploader/__version__.py$' | awk '{ print "  " $0 }'
	exit 1
fi

if ! git commit -m "chore: release ${tag_name:1}"
then
	echo "Error: git commit failed"
	exit 1
fi

if ! git tag -a "$tag_name" -m "# version ${tag_name:1}"
then
	echo "Error: creating the tag failed"
	exit 1
fi

if ! python -m twine upload -u __token__ -p "$pypi_token" dist/*
then
	echo "Error: upload to pypi failed"
	exit 1
fi

git push origin master
git push origin "$tag_name"

