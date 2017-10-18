#!/bin/bash
if [ -n "$DEBUG" ]
then
  set -x
fi
set -euo pipefail
# ref: https://coderwall.com/p/fkfaqq/safer-bash-scripts-with-set-euxo-pipefail

PYTHON_VERSIONS=`ls /opt/python/`

# Avoid creation of __pycache__/*.py[c|o]
export PYTHONDONTWRITEBYTECODE=1

package_name="$1"
if [ -z "$package_name" ]
then
    &>2 echo "Please pass package name as a first argument of this script ($0)"
    exit 1
fi

arch=`uname -m`

echo
echo
echo "Compile wheels"
for PYTHON in ${PYTHON_VERSIONS}; do
    /opt/python/${PYTHON}/bin/pip wheel /io/ -w /io/dist/
done

echo
echo
echo "Bundle external shared libraries into the wheels"
for whl in /io/dist/${package_name}-*-linux_${arch}.whl; do
    echo "Repairing $whl..."
    auditwheel repair "$whl" -w /io/dist/
done

echo
echo
echo "Cleanup OS specific wheels"
rm -fv /io/dist/*-linux_*.whl

echo
echo
echo "Cleanup non-$package_name wheels"
find /io/dist -maxdepth 1 -type f ! -name "$package_name"'-*-manylinux1_'"$arch"'.whl' -print0 | xargs -0 rm -rf

echo
echo
echo "Install packages and test"
echo "dist directory:"
ls /io/dist

for PYTHON in ${PYTHON_VERSIONS}; do
    # clear python cache
    find /io -type d -name __pycache__ -print0 | xargs -0 rm -rf

    echo
    echo -n "Test $PYTHON: "
    /opt/python/${PYTHON}/bin/python -c "import platform; print('Building wheel for {platform} platform.'.format(platform=platform.platform()))"
    /opt/python/${PYTHON}/bin/pip install "$package_name"[testing,webassets] -f file:///io/dist
    /opt/python/${PYTHON}/bin/nosetests -v --with-coverage --cover-package="$package_name" --cover-erase /io/tests
done
