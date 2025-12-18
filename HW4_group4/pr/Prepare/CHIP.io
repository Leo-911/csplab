(globals
    version = 3
    io_order = default
)

(iopad
    (topright
        (inst name="CORNERTR")
    )
    (top
        (inst name="  " skip=60)        
        (inst name="CORE_PG1")
        (inst name="IO_PG1")
        (endspace gap=60.48)
    )
    (topleft    
        (inst name="CORNERTL" orientation=MX)
    )
    (left 
        (inst name=" "  skip=60)     
        (inst name="IO_PG2" orientation=MX90 skip=60)
        (inst name="CORE_PG2" orientation=MX90)        
        (endspace gap=35.48)
    )
    (bottomleft
        (inst name="CORNERBL")
    )
    (bottom
        (inst name="  " skip=60)
        (inst name="CORE_PG3" orientation=MY)
        (inst name="IO_PG3" )
        (endspace gap=60.48)
    )
    (bottomright
        (inst name="CORNERBR" orientation=MY)
    )
    (right
        (inst name="  " skip=60)
        (inst name="IO_PG4" orientation=MY90 skip=60)
        (inst name="CORE_PG4")
        (endspace gap=35.48)
    )
)
