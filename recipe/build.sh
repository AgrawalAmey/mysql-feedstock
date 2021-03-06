#!/bin/bash

# this script is based off the homebrew package:
# https://github.com/Homebrew/homebrew-core/blob/master/Formula/mysql.rb

# make sure we can find cpp on the linux CI service
if [[ `uname` != "Darwin" ]]
then
    CPP_ROOT=`dirname ${CPP}`
    export LC_ALL=C  # on osx sed chokes on non UTF-8
    find . -type f -print0 | xargs -0 sed -i"" -e "s|COMMAND rpcgen  -C|COMMAND rpcgen  -Y ${CPP_ROOT} -C|g"
    unset LC_ALL

    # make sure the cmake build can find everything
    ln -s ${CPP} `dirname ${CPP}`/cpp
else
    export CPPFLAGS=${CPPFLAGS%" -mmacosx-version-min=10.9"}
fi

mkdir -p build
cd build

export CXXFLAGS="-fpermissive "${CXXFLAGS}

# -DINSTALL_* are relatiove to -DCMAKE_INSTALL_PREFIX
# I checked and the bundled libs don't cause any issues with stomping
# on the conda-forge packages. Thus I am going to go with them for now since
# with the anaconda compilers I cannot convince the build to link properly.
mkdir -p ${PREFIX}/mysql
cmake \
    -DCMAKE_C_FLAGS=${CFLAGS}" "${LDFLAGS} \
    -DCMAKE_CXX_FLAGS=${CXXFLAGS}" "${LDFLAGS} \
    -DCMAKE_PREFIX_PATH=${PREFIX} \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DINSTALL_INCLUDEDIR=include/mysql \
    -DINSTALL_MANDIR=share/man \
    -DINSTALL_DOCDIR=share/doc/mysql \
    -DINSTALL_DOCREADMEDIR=mysql \
    -DINSTALL_INFODIR=share/info \
    -DINSTALL_MYSQLSHAREDIR=share/mysql \
    -DINSTALL_SUPPORTFILESDIR=mysql/support-files \
    -DINSTALL_SCRIPTDIR=mysql/scripts \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_FIND_FRAMEWORK=LAST \
    -DCMAKE_VERBOSE_MAKEFILE=OFF \
    -Wno-dev \
    -DWITH_UNIT_TESTS=OFF \
    -DDEFAULT_CHARSET=utf8 \
    -DDEFAULT_COLLATION=utf8_general_ci \
    -DCOMPILATION_COMMENT=conda-forge \
    -DWITH_SSL=bundled \
    -DWITH_EDITLINE=bundled \
    -DWITH_BOOST=bundled \
    -DDOWNLOAD_BOOST=1 \
    .. &> cmake.log

make
make install &> install.log

# remove this dir so we do not ship it
cd ${PREFIX}/mysql-test
mysql_temp_dir=`mktemp -d ${TMPDIR}/tmp/XXXXXXXXXXXX`
{
    set -e
    # the || here is a rough try...except
    perl mysql-test-run.pl status --vardir=${mysql_temp_dir} || rm -rf ${mysql_temp_dir}
}
cd -
# always delete anything left
rm -rf ${mysql_temp_dir}
rm -rf ${PREFIX}/mysql-test

# Make a symlink to script to start the server directly.
ln -s ${PREFIX}/mysql/support-files/mysql.server ${PREFIX}/bin/mysql.server
