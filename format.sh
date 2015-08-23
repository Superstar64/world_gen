Style="--indent_style=tab --brace_style=otbs"
if test "$#" -eq 0; then
	for i in $(find source -type f); 
	do 
		dfmt $Style --inplace $i;
	done;
else
	for i in "$@";
	do
		dfmt $Style --inplace source/$i
	done;
fi
