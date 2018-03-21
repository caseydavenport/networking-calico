#!/bin/bash -ex

# Build RPM from the current working tree.

# Get the location of this script.  Other scripts that we use must be in the
# same location.
scriptdir=$(dirname $(readlink -f $0))

# Include function library.
. ${scriptdir}/lib.sh

repo=`git_repo_root`
pkg=`infer_package_name`
# Remove a possible 'calico-' prefix.
pkg=${pkg#calico-}
spec=${repo}/rpm/${pkg}.spec

# Infer the version that the spec wants to build.
version=`grep Version: $spec | awk '{print $2;}'`

# Copy the source to a temporary directory named ${pkg}-${version}.
blddir=`mktemp -t -d build-rpm.XXXXXXXXXX`
pushd ${blddir}
dir=${pkg}-${version}
cp -a ${repo} ${dir}

# Tar that up into the rpm directory, then delete the copy.
tar zcf ${repo}/rpm/${dir}.tar.gz ${dir}
popd
rm -rf ${blddir}

# jenkins-slave2
rpmbuilddir=`gcloud compute ssh --project unique-caldron-775 jenkins@jenkins-slave2 -- mktemp -t -d rpmbuild.XXXXXXX`
gcloud compute ssh --project unique-caldron-775 jenkins@jenkins-slave2 <<EOF
set -ex
mkdir ${rpmbuilddir}/SPECS
mkdir ${rpmbuilddir}/SOURCES
EOF
pushd ${repo}/rpm
gcloud compute copy-files --project unique-caldron-775 * jenkins@jenkins-slave2:${rpmbuilddir}/SOURCES/
gcloud compute copy-files --project unique-caldron-775 ${spec} jenkins@jenkins-slave2:${rpmbuilddir}/SPECS/
gcloud compute ssh --project unique-caldron-775 jenkins@jenkins-slave2 <<EOF
set -ex
cd ${rpmbuilddir}
rpmbuild --define '_topdir ${rpmbuilddir}' -ba SPECS/${pkg}.spec
gpg --list-secret-keys "Neil Jerram (key for Project Calico work) <Neil.Jerram@metaswitch.com>"
rpm --define '_gpg_name Neil Jerram (key for Project Calico work) <Neil.Jerram@metaswitch.com>' --resign RPMS/*/*.rpm
EOF
gcloud compute copy-files --project unique-caldron-775 jenkins@jenkins-slave2:${rpmbuilddir}/RPMS/noarch/*.rpm . || true
gcloud compute copy-files --project unique-caldron-775 jenkins@jenkins-slave2:${rpmbuilddir}/RPMS/x86_64/*.rpm . || true
gcloud compute ssh --project unique-caldron-775 jenkins@jenkins-slave2 <<EOF
set -ex
rm -rf ${rpmbuilddir}
EOF
rm -rf ${repo}/rpm/${dir}.tar.gz
