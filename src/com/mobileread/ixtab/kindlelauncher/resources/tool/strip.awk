#!/usr/bin/gawk -f

function kprint(txt,      pre,cmp)
{
#debug#	if(pre) printf ("%4d::%s::\t%s\n\t\t", NR, pre, cmp)
	if (pre ~ /^kp/) {
		print txt
		sub(/^[[:space:]]+/, "", txt)
		printf "%3d to be safe didn't change %4d: %s\n",++TOBESAFE, NR, txt >"/dev/stderr"
	} else {
		sprint(txt)
	}
}

function sprint(txt)
{
	if (AWK)
		sub(/^[[:space:]]+/, "", txt) # safe in AWK only - sh syntax supports multiline string literals
	print txt
}

BEGIN	{
	if ("" == WARN || 0 != WARN) {
WARNING="=== Non-greedy shell/AWK script comment stripper ==="\
"\nThe following input syntax WILL result in incorrect output, so rid your"\
"\nscript of such syntax before stripping it - You have been warned!"\
"\n. Hash comments within multi-line strings"\
"\n    x=\"this is NOT"\
"\n    # a comment"\
"\n  but it will be recognized as such and be removed (incorrectly)"\
"\n\nYou may suspend stripping a text block altogether (Stop/Resume):"\
"\n  :#? SSTR ..."\
"\n  a block of text"\
"\n  :#? RSTR ..."\
"\nYou may force stripping (Begin/End): /:#? BSTR .../,/#?: ESTR .../"\
"\n\nBest practice to get more stripping:"\
"\n  (definition: an 'in-line comment' line includes some non-white characters before '#')"\
"\n. In in-line comments replace ' and \" with ` (backtick)"\
"\n. In in-line comments do not use literal '#' in the text of the comment itself"\
"\n"
		print WARNING >"/dev/stderr"
	}

	if ("" == PROMPT || 0 != PROMPT) {
PROMPT="Usage: strip.awk [-v AWK=1] [-v WARN=0] [-v PROMPT=0] script.sh > new_script.sh"\
"\tAWK=1 further optimizes AWK input"\
"\nPress any key to strip '"ARGV[1]"' to stdout ..."
		printf PROMPT >"/dev/stderr"
		getline <"/dev/stdin"
	}

	CONTINUATION=0
	SUSPENDED=0
}
# suspend stripping
{
	if ($0 ~ /^[[:space:]]*#?: RSTR\>/) { SUSPENDED=0; next }
	else if ($0 ~ /^[[:space:]]*#?: SSTR\>/) { SUSPENDED=1; next }
	else if (SUSPENDED) { sprint($0); next }
}
# forced stripping
/^[[:space:]]*#?: BSTR\>/,/^[[:space:]]*#?: ESTR\>/ {
	next
}
# commented continuation line isn't a continuation
/\\$/ && /^[[:space:]]*#/ {
	next
}
# continuation line
/\\$/ {
	CONTINUATION=1
	sprint($0); next
}
# white line
/^[[:space:]]*$/	{
	if (CONTINUATION) { # unless after continuation
		sprint($0)
		CONTINUATION=0
	}
	next
}
# all other lines
{
	CONTINUATION=0
}
# full comment line
/^[[:space:]]*#/ {
	if (2>=NR) print # unless shebang and version info comment
	next
}
# in-line comment not in string nor in variable substitution
/#/ && ! ( /["']/ || /\${/ ) {
	match($0,/[[:space:]]*#[^#]*$/) # non-greedy => look for tail comment
	s=substr($0,1,RSTART-1)
	t=substr($0,RSTART+1,RLENGTH-1) # $0 == s"#"t
	r1=substr(s,length(s),1)
	if (r1 == "$") {
		kprint($0,"kp0",$0); # $#
		next
	}
	kprint(s,"not",$0);
	next
}
# in-line comment possibly in string or in variable substitution
/#/ {
	match($0,/[[:space:]]*#[^#]*$/) # non-greedy => look for tail comment
	s=substr($0,1,RSTART-1)
	t=substr($0,RSTART+1,RLENGTH-1) # $0 == s"#"t
	r1=substr(s,length(s),1)
	if (r1 == "$") {
		kprint($0,"kp1",$0); # $#
		next
	}
	if (t !~ /["'}]/) {
		# tail comment is free from str and var
		kprint(s,"tai",$0)
		next
	}
	kprint($0,"kp2",$0)
	next
}
# all remaining lines
{
	sprint($0)
}
