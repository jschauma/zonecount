#set title 'Domains under .::TLD::' font "Verdana, 40"

set xdata time
set timefmt "%Y%m%d"

#set xlabel "Date" font "Verdana, 20" 
#set ylabel "# in millions" font "Verdana, 20" offset -2

set format x "%Y%m%d"
set format y "%'.0f"
set terminal pngcairo size 2048,768 enhanced font "Verdana, 10"

set lmargin 15
set rmargin 15
set tmargin 5
set bmargin 5

set grid
unset key

set style line 1 \
    linecolor rgb '#0060ad' \
    linetype 1 linewidth 2 \
    pointtype 7 pointsize 1.5

set output '/misc/dnsdata/zonecount/html/::TLD::/::TLD::.png'
plot '/misc/dnsdata/zonecount/counts/::TLD::' using 1:2 title '::TLD::' with linespoints linestyle 1
