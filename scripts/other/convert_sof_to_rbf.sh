#!/bin/bash

chmod +x ../parameters.sh
source ../parameters.sh

$QUARTUS_ROOTDIR/bin/quartus_cpf -c -o bitstream_compression=on ../../output_files/f2h_uart.sof soc_system.rbf

