#!/bin/bash
# Note: execute from the project root directory

set -x

EXPORT="./dist/build/export/export"

# when executed without parameters shows usage
if [[ `$EXPORT | head -n 2 | tail -n 1` != "Usage: export metadata.db repo dest thing [thing ...]" ]]; then
    exit 1
fi

############################################################
### Prepare for testing export functionality

IMPORT="./dist/build/import/import"
CS_REPO="./export.repo"
METADATA_DB="./export_metadata.db"
EXPORT_DIR="./exported-content.d/"
OSTREE_DIR="./ostree-content.d/"

sqlite3 $METADATA_DB < ../schema.sql

# filesystem package is required by the exporter
$IMPORT $METADATA_DB $CS_REPO http://mirror.centos.org/centos/7/os/x86_64/Packages/filesystem-3.2-21.el7.x86_64.rpm
# setup package is required since 5834760
$IMPORT $METADATA_DB $CS_REPO http://mirror.centos.org/centos/7/os/x86_64/Packages/setup-2.8.71-7.el7.noarch.rpm

# these two packages both provide /usr/lib64/libcmpiCppImpl.so
# normally libcmpiCppImpl0 lives in the @conflicts group
$IMPORT $METADATA_DB $CS_REPO http://mirror.centos.org/centos/7/os/x86_64/Packages/tog-pegasus-libs-2.14.1-3.el7.x86_64.rpm
$IMPORT $METADATA_DB $CS_REPO http://mirror.centos.org/centos/7/os/x86_64/Packages/libcmpiCppImpl0-2.0.3-5.el7.x86_64.rpm

# import last so we don't have to parse the commit log to figure out what "HEAD" is
$IMPORT $METADATA_DB $CS_REPO http://mirror.centos.org/centos/7/os/x86_64/Packages/yum-rhn-plugin-2.0.1-6.el7.noarch.rpm


############################################################
## When exporting a non-existing package
## Then returns an error

OUTPUT=`sudo $EXPORT $METADATA_DB $CS_REPO $EXPORT_DIR filesystem-3.2-21.el7.x86_64 NON-EXISTING`
RETVAL=$?

if [[ "$OUTPUT" != '"No such group NON-EXISTING"' ]]; then
    echo "ERROR: Error output doesn't match"
    exit 1
fi

if [[ $RETVAL == 0 ]]; then
    echo "ERROR: On error exit code should not be zero"
    exit 1
fi

sudo rm -rf $EXPORT_DIR

############################################################
## When exporting existing package
## Then exported contents match the export from an ostree checkout

sudo $EXPORT $METADATA_DB $CS_REPO $EXPORT_DIR filesystem-3.2-21.el7.x86_64 setup-2.8.71-7.el7.noarch yum-rhn-plugin-2.0.1-6.el7.noarch

if [[ $? != 0 ]]; then
    echo "ERROR: Exit code should be zero"
    exit 1
fi

# Make an ostree checkout to use for comparisons
sudo ostree --repo=$CS_REPO checkout master $OSTREE_DIR
if [[ $? != 0 ]]; then
    echo "ERROR: ostree exit code should be zero"
    exit 1
fi

for BASE_FILE in `find $OSTREE_DIR -type f`; do
    echo "... examining $BASE_FILE"
    EXPECTED_FILE=`echo $BASE_FILE | sed "s|$OSTREE_DIR|$EXPORT_DIR|"`

    if [[ ! -f "$EXPECTED_FILE" ]]; then
        echo "ERROR: $EXPECTED_FILE doesn't exist"
        exit 1
    fi

    BASE_SHA256=`sha256sum $BASE_FILE | cut -f1 -d' '`
    EXPECTED_SHA256=`sha256sum $EXPECTED_FILE | cut -f1 -d' '`

    if [[ $BASE_SHA256 != $EXPECTED_SHA256 ]]; then
        echo "ERROR: $BASE_SHA256($BASE_FILE) != $EXPECTED_SHA256($EXPECTED_FILE)"
        exit 1
    fi
done

sudo rm -rf $EXPORT_DIR
sudo rm -rf $OSTREE_DIR

############################################################
## When exporting two conflicting packages
## Then reports an error

# in libcmpiCppImpl0:
# libcmpiCppImpl.so and libcmpiCppImpl.so.0 are symlinks to libcmpiCppImpl.so.0.0.0

# in tog-pegasus-libs:
# libcmpiCppImpl.so is a symlink to libcmpiCppImpl.so.1

# the conflicting file is the libcmpiCppImpl.so symlink

# first tog-pegasus-libs, second libcmpiCppImpl0
OUTPUT=`sudo $EXPORT $METADATA_DB $CS_REPO $EXPORT_DIR filesystem-3.2-21.el7.x86_64 setup-2.8.71-7.el7.noarch tog-pegasus-libs-2:2.14.1-3.el7.x86_64 libcmpiCppImpl0-2.0.3-5.el7.x86_64 2>&1`
RETVAL=$?

if [[ $RETVAL == 0 ]]; then
    echo "ERROR: Exit code should be non-zero"
    exit 1
fi

# conflict is in libcmpiCppImpl0 which is the second package in the list
if [[ "$OUTPUT" != 'export: libcmpiCppImpl.so.0.0.0: createSymbolicLink: already exists (File exists)' ]]; then
    echo "ERROR: Error output doesn't match"
    exit 1
fi
sudo rm -rf $EXPORT_DIR


# first libcmpiCppImpl0, second tog-pegasus-libs
OUTPUT=`sudo $EXPORT $METADATA_DB $CS_REPO $EXPORT_DIR filesystem-3.2-21.el7.x86_64 setup-2.8.71-7.el7.noarch libcmpiCppImpl0-2.0.3-5.el7.x86_64 tog-pegasus-libs-2:2.14.1-3.el7.x86_64 2>&1`
RETVAL=$?

if [[ $RETVAL == 0 ]]; then
    echo "ERROR: Exit code should be non-zero"
    exit 1
fi

# conflict is in tog-pegasus-libs which is the second package in the list
if [[ "$OUTPUT" != 'export: libcmpiCppImpl.so.1: createSymbolicLink: already exists (File exists)' ]]; then
    echo "ERROR: Error output doesn't match"
    exit 1
fi
sudo rm -rf $EXPORT_DIR
