
# Usage: ./setup.sh <letter A|B|C|D|E>

input_file="certora/specs/teller_basic.spec"
num_lines=9

letter="$1"
replacement_file="certora/scripts/header${letter}.spec"
output_file=$input_file

tail_lines=$(tail -n +$((num_lines + 1)) "$input_file" 2>/dev/null || echo "")

cat "$replacement_file" > "$output_file"
echo "$tail_lines" >> "$output_file"
