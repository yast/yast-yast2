# yast2 completion
# A Christmas gift from Carsten Hoeger

# build a list of know yast modules
MODLIST=($(LC_ALL=C yast -l| grep '^[a-z]' | grep -v "Available"))

_yast2 ()
{
        local cur prev len idx mod

	if [[ ${#COMP_WORDS[@]} -gt 4 ]]; then
		return 0
	fi
        cur=${COMP_WORDS[COMP_CWORD]}
        prev=${COMP_WORDS[COMP_CWORD-1]}
	if [[ ${#COMP_WORDS[@]} -ge 3 ]]; then
	    prevprev=${COMP_WORDS[COMP_CWORD-2]}
	fi
        if [[ $cur == '-' ]]; then
                COMPREPLY=(-h -l -g -s)
                return 0
        fi

	# iterate through all yast modules
	for mod in ${MODLIST[@]}; do
	    # if argument before last argument is a yast module, 
	    # check it's available options
	    if [[ -n $prevprev && $prevprev == $mod ]]; then
		# build option list
		# prev is a module option
		MODOPTS=($(LC_ALL=C yast $mod $prev help 2>&1| perl -e '
use strict;
while(<>) {
last if $_ =~ /^\s+Options/;
}
while(<>) {
last if $_ =~ /^\s+$/;
$_ =~ /^\s+(\w+)\s.*/;
print "$1\n";
}
'))
		len=${#cur}
		idx=0
		for pval in ${MODOPTS[@]}; do
		    if [[ "$cur" == "${pval:0:$len}" ]]; then
                        COMPREPLY[$idx]=$pval
                        idx=$[$idx+1]
		    fi
		done
		return 0
	    fi
	    # previous option is a known yast module?
	    if [[ $prev == $mod ]]; then
		# build option list
		MODOPTS=($(LC_ALL=C yast $mod help 2>&1| perl -e '
use strict;
while(<>) {
last if $_ =~ /^Commands/;
}
while(<>) {
last if $_ =~ /^\s+$/;
$_ =~ /^\s+(\w+)\s.*/;
print "$1\n";
}
'))
		len=${#cur}
		idx=0
		for pval in ${MODOPTS[@]}; do
		    if [[ "$cur" == "${pval:0:$len}" ]]; then
                        COMPREPLY[$idx]=$pval
                        idx=$[$idx+1]
		    fi
		done
		return 0
	    fi
	done

        len=${#cur}
        idx=0
        for pval in ${MODLIST[@]}; do
                if [[ "$cur" == "${pval:0:$len}" ]]; then
                        COMPREPLY[$idx]=$pval
                        idx=$[$idx+1]
                fi
        done
        return 0
}
complete -F _yast2 yast2
complete -F _yast2 yast
