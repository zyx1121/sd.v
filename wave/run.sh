echo "開始編譯"

iverilog -o wave/wave *.v

echo "編譯完成"

echo "生成波形..."

vvp wave
