#!/bin/bash

# Grub2 Build for Super Grub2 Disk - Clean build dir and update (pull)

SG2D_DIR="$(pwd)"

# Git check

if git --version > /dev/null 2>&1 ; then
	:
else
	echo -e -n "Git was not found. Git is needed\n";
	echo -e -n "Aborting\n";
	exit 3

fi

source grub-build-config

# Check if build directories exists or not.
# If anyone of them does not exist exit with an error.

for n_build_dir in "${!SG2D_GRUB_BUILD_DIRS_ARR[@]}"; do

	if [ ! -d "${SG2D_GRUB_BUILD_DIRS_ARR[n_build_dir]}" ] ; then
		echo -e -n "Clean and build refuses to continue\n";
		echo -e -n "'${SG2D_GRUB_BUILD_DIRS_ARR[n_build_dir]}' does not exist\n";
		echo -e -n "Have you run: ./grub-build-001-prepare-build.sh ?\n";
		exit 2
	fi

done

for n_build_dir in "${!SG2D_GRUB_BUILD_DIRS_ARR[@]}"; do
	cd "${SG2D_GRUB_BUILD_DIRS_ARR[n_build_dir]}"
	# Reset git to have a clean state
	git reset --hard
	git clean -f -d
	git clean -f -x -d
	# Checkout master so that we can pull last version
	git checkout master
	# Pull last version just in case we are requesting a new commit
	# not found or our local copy of git
	git pull
	# Finally checkout the requested commit
	git checkout "${GRUB2_COMMIT}"
done


cd "${SG2D_DIR}"