#!/bin/bash
#
# This script generates methods to allow our API objects to describe themsleves for the Swagger tool
# by reading the current version of the Godoc for the objects. This script can either generate new
# documentation or verify that the documentation currently in the repository remains valid.
#
# This script accepts the following parameters as environment variables:
#  - VERIFY:  run the script to verify current documentation
#  - DRY_RUN: print which files would be generated and exit
source "$(dirname "${BASH_SOURCE}")/lib/init.sh"

# read in envar options
verify="${VERIFY:-}"
dryrun="${DRY_RUN:-}"

mkdir -p /tmp/openshift/generate/swaggerdoc

os::util::ensure::built_binary_exists 'genswaggerdoc'

source_files="$( find_files | grep -E '/v1/types.go' )"

if [[ -n "${dryrun}" ]]; then
	echo "The following files would be read by $0:"
	for file in ${source_files}; do
		echo "${file}"
	done
	exit 0
fi

failed='false'
for file in ${source_files}; do
	swagger_file="$( dirname "${file}" )/swagger_doc.go"
	if ! genswaggerdoc --input="${file}" --verify >/tmp/openshift/generate/swaggerdoc/verify.txt 2>&1; then
		echo "[ERROR] Errors in \"${file}\" must be addressed before Swagger documentation can be generated:"
		cat /tmp/openshift/generate/swaggerdoc/verify.txt
		failed='true'
	else
		tmp_output_file="/tmp/openshift/generate/swaggerdoc/${swagger_file}"
		mkdir -p "$( dirname "${tmp_output_file}" )"
		package="$( dirname "${file}" )";
		echo "package ${package##*/}" > "${tmp_output_file}"
		echo "
// This file contains methods that can be used by the go-restful package to generate Swagger
// documentation for the object types found in 'types.go' This file is automatically generated
// by hack/update-generated-swagger-descriptions.sh and should be run after a full build of OpenShift.
// ==== DO NOT EDIT THIS FILE MANUALLY ====
" >> "${tmp_output_file}"
		genswaggerdoc --input="${file}" --output="${tmp_output_file}"
		gofmt -s -w "${tmp_output_file}"

		if [[ -n "${verify}" ]]; then
			if ! diff --new-file --unified=3 --text "${tmp_output_file}" "${swagger_file}"; then
				echo "[ERROR] Generated Swagger documentation at \"${swagger_file}\" is out of date."
				failed='true'
			else
				os::log::info "Verified that generated Swagger documentation at \"${swagger_file}\" is up to date."
			fi
		else
			mv "${tmp_output_file}" "${swagger_file}"
			os::log::info "Generated Swagger documentation written for \"${file}\" to \"${swagger_file}\""
		fi
	fi
done

verb="generation"
if [[ -n "${verify}" ]]; then
	verb="verification"
fi

if [[ "${failed}" = "true" ]]; then
	echo "[FAILURE] Swagger API object self-documentation ${verb} failed"
	exit 1
fi

echo "[SUCCESS] Swagger API object self-documentation ${verb} succeeded"