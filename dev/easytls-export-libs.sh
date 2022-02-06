#!/bin/sh

print() { printf "%s\n" "* $*"; }
die() { print "ERROR: $err_msg : $*"; exit 1; }

# print top part (READ)
p_top ()
{
	err_msg="p_top: ${begin}"
	print_line=1
	{
		#IFS=''
		while read -r line
		do
			[ $print_line ] && printf '%s\n' "${line}"
			[ "${line}" = "${begin}" ] && break
		done < "${src_f}"
	} > "${src_f}.top" || return 9
	unset err_msg line print_line
}

# insert lib (READ)
p_mid ()
{
	err_msg="p_mid: ${begin} ${end}"
	unset print_line
	{
		while read -r line
		do
			[ "${line}" = "${begin}" ] && print_line=1 && continue
			[ "${line}" = "${end}" ] && unset print_line
			[ $print_line ] && printf '%s\n' "${line}"
			:
		done < "${lib_f}"
	} > "${src_f}.mid" || return 9
	unset err_msg line print_line
}

# print end part (READ)
p_end ()
{
	err_msg="p_end: ${end}"
	unset print_line
	{
		while read -r line
		do
			[ "${line}" = "${end}" ] && print_line=1
			[ $print_line ] && printf '%s\n' "${line}"
			:
		done < "${src_f}"
	} > "${src_f}.end" || return 9
	unset err_msg line print_line
}

# Combine parts to new
# (WRITE)
f_cat ()
{
	err_msg="f_cat: ${src_f}"
	cp --attributes-only "${src_f}" "${src_f}.new"
	cat "${src_f}.top" "${src_f}.mid" "${src_f}.end" >> "${src_f}.new" || \
		die "f_cat: cat"
	unset err_msg
}

# move new to souce
# (WRITE)
f_mv ()
{
	err_msg="f_mv: ${src_f}"
	mv -f "${src_f}.new" "${src_f}" || \
		die "f_mv: mv"
	unset err_msg
}

# delete temp
# (WRITE)
f_rm ()
{
	err_msg="f_rm: ${src_f}"
	rm -f "${src_f}.top" "${src_f}.mid" "${src_f}.end" || \
		die "f_rm: rm"
	unset err_msg
}

export_lib ()
{
	save_IFS="${IFS}"
	IFS=''

	p_top || return $?
	p_mid || return $?
	p_end || return $?
	f_cat || return $?
	f_mv || return $?
	f_rm || return $?

	IFS="${save_IFS}"

}

################

f_et_top ()
{
	print_line=1
	{
		while read -r line
		do
			[ $print_line ] && printf '%s\n' "${line}"
			[ "${line}" = "${begin}" ] && break
		done < "${src_et}"
	} > "${dst_et1}" || return 9
}

f_et_mid ()
{
	unset print_line
	{
		while read -r line
		do
			[ "${line}" = "${begin}" ] && print_line=1 && continue
			[ "${line}" = "${end_et}" ] && unset print_line
			[ $print_line ] && printf '%s\n' "${line}"
			:
		done < "${src_tl}"
	} > "${dst_et2}" || return 9
}

f_et_end ()
{
	unset print_line
	{
		while read -r line
		do
			[ "${line}" = "${end_et}" ] && print_line=1
			[ $print_line ] && printf '%s\n' "${line}"
			:
		done < "${src_et}"
	} > "${dst_et3}" || return 9
}

f_et_mv ()
{
	cat "${dst_et1}" "${dst_et2}" "${dst_et3}" >> "${src_et}.new"
	mv -f "${src_et}.new" "${src_et}"
	rm -f "${dst_et1}" "${dst_et2}" "${dst_et3}"
}

f_cc_top ()
{
	print_line=1
	{
		while read -r line
		do
			[ $print_line ] && printf '%s\n' "${line}"
			[ "${line}" = "${begin}" ] && break
		done < "${src_cc}"
	} > "${dst_cc1}" || return 9
}

f_cc_mid ()
{
	unset print_line
	{
		while read -r line
		do
			[ "${line}" = "${begin}" ] && print_line=1 && continue
			[ "${line}" = "${end_cc}" ] && unset print_line
			[ $print_line ] && printf '%s\n' "${line}"
			:
		done < "${src_tl}"
	} > "${dst_cc2}" || return 9
}

f_cc_end ()
{
	unset print_line
	{
	while read -r line
	do
		[ "${line}" = "${end_cc}" ] && print_line=1
		[ $print_line ] && printf '%s\n' "${line}"
		:
	done < "${src_cc}"
	} > "${dst_cc3}" || return 9
}

f_cc_mv ()
{
	cat "${dst_cc1}" "${dst_cc2}" "${dst_cc3}" >> "${src_cc}.new"
	mv -f "${src_cc}.new" "${src_cc}"
	rm -f "${dst_cc1}" "${dst_cc2}" "${dst_cc3}"
}

tctip_lib ()
{
	# easytls-tctip.lib

	begin="#=# 9273398a-5284-4c1f-aec5-d597ceb1d085"

	end_et="#=# 7f97f537-eafd-40c3-8f31-2fee10c12ad3"
	end_cc="#=# b66633f8-3746-436a-901f-29638199b187"

	src_tl="./dev/easytls-tctip.lib"
	if [ ! -f "${src_tl}" ]; then
		echo "Usage: Run this from ./easytls directory"
		echo "       ./dev/easytls-export-tctip-lib.sh"
		exit 1
	fi

	src_et="./easytls"
	dst_et1="${src_et}.tmp1"
	dst_et2="${src_et}.tmp2"
	dst_et3="${src_et}.tmp3"
	rm -f "${dst_et1}" "${dst_et2}" "${dst_et3}" "${src_et}.new"
	cp --attributes-only "${src_et}" "${src_et}.new"

	src_cc="./easytls-client-connect.sh"
	dst_cc1="${src_cc}.tmp1"
	dst_cc2="${src_cc}.tmp2"
	dst_cc3="${src_cc}.tmp3"
	rm -f "${dst_cc1}" "${dst_cc2}" "${dst_cc3}" "${src_cc}.new"
	cp --attributes-only "${src_cc}" "${src_cc}.new"

	save_IFS="${IFS}"
	IFS=''

	# Old way

	print "tctip library"

	print "easytls"
	f_et_top || return 11
	f_et_mid || return 12
	f_et_end || return 13
	f_et_mv || return 14

	print "easytls-client-connect.sh"
	f_cc_top || return 21
	f_cc_mid || return 22
	f_cc_end || return 23
	f_cc_mv || return 24

	IFS="${save_IFS}"
}

#################

tctip_lib || die "tctip_lib: $?"

# New way
print "metadata library"
src_f="easytls"
lib_f="./dev/easytls-metadata.lib"
begin="#=# 35579017-b084-4d6b-94d5-76397c2d4a1f"
end="#=# 70b4ec32-f1fc-47fb-a261-f02e7f572b62"

export_lib || die "export_lib: $lib_f"
