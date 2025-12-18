set diearea [get_db designs .bbox] 
puts "Die area : [join $diearea " "]"
set outfile [open "DieArea" w+]
puts $outfile "Die area : [join $diearea " "]"
close $outfile
