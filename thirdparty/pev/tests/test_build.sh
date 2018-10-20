#!/bin/bash

report_file=${now}_${so}_${arch}_$(basename $0 .sh).log

report()
{
	if [ -z "$1" ]; then
		while read l; do
			echo "$l" >> $report_file
		done <&0
		echo >> $report_file
	else
		echo -e "$1\n" >> $report_file
	fi
}

report_status() { [ "$1" -eq 0 ] && report '>>> SUCCESS' || report '>>> FAILED'; }

cd ..
report \
"pev test report
----------------
Type: $(basename $0 .sh)
Date: $now
Arch: $arch
Version: $version"

echo -n "Compiling... "
make clean >/dev/null 2>&1
make 2>&1 | report
pipe=${PIPESTATUS[0]}
[ "$pipe" -eq 0 ] && echo ok || echo failed
report_status $pipe

mv "$report_file" tests/
cd tests

echo -e "\nReport: $report_file, $(wc -l $report_file | cut -d' ' -f1) lines, \
$(ls -lh $report_file | cut -d' ' -f5)."
