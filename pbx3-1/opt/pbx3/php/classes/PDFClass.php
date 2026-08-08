<?php
// PDF class
// more or less a straight lift from the fpdf examples(http://www.fpdf.org)
// Developed by CoCo
//
// Copyright (c) Aelintra Telecom Limited
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//

require('fpdf.php');

class PDF extends FPDF {

public $pageHeading;
public $leftMargin;
public $pageHeader;
public $colWidths;

function pdfTable($header, $data, $w) {
	$this->pageHeader = $header;
	$this->colWidths = $w;
	$this->AliasNbPages('{totalPages}');
    // Colors, line width and bold font
    $this->SetTitle("PBX3 PDF print");
    $this->SetFillColor(255,0,0);
    $this->SetTextColor(255);
    $this->SetDrawColor(128,0,0);
    $this->SetLineWidth(.2);
    $this->SetFont('Arial','',8);

// First Header
    
    for($i=0;$i<count($header);$i++)
        $this->Cell($w[$i],7,$header[$i],1,0,'C',true);
    $this->Ln();

// Color and font restoration
    $this->SetFillColor(224,235,255);
    $this->SetTextColor(0);
    $this->SetFont('');
    
// Data
    $fill = false;
    foreach($data as $row) {
    	$i=0;
    	foreach ($row as $column) {
    		if (strlen($column) > $w[$i] / 2) {
    			$maxlen = $w[$i] / 2;
    			$oCol = substr($column,0,$maxlen) . '(T)';
    		}
    		else {
    			$oCol = $column;
    		}
	       	$this->Cell($w[$i],6,$oCol,'LR',0,'L',$fill);
        	$i++;
        }
        $this->Ln();
        $fill = !$fill;
    }
    // Closing line
    $this->Cell(array_sum($w),0,'','T');
}

function Header() {
    if ($this->leftMargin) {
    	$this->SetLeftMargin($this->leftMargin);
	}
 
    // Select Arial bold 15
    $this->SetFont('Arial','B',15);

    // Framed title
    $this->Cell(60,10,$this->pageHeading,1,0,'C');
    // Line break
    $this->Ln(20);
    
// subsequent headers
    $this->SetFillColor(255,0,0);
    $this->SetTextColor(255);
    $this->SetDrawColor(128,0,0);
    $this->SetLineWidth(.2);
    $this->SetFont('Arial','',8);  
    if (isset($this->pageHeader)) { 
    	for($i=0;$i<count($this->pageHeader);$i++)
        	$this->Cell($this->colWidths[$i],7,$this->pageHeader[$i],1,0,'C',true);
    }
    $this->Ln();       
}

function Footer()
{
    $currentDate = date("j/n/Y");
    // Go to 1.5 cm from bottom
    $this->SetY(-15);
    // Select Arial italic 8
    $this->SetFont('Arial','I',8);
    // Print centered page number
    $this->Cell(0,10,'Printed by PBX3 - ' . $currentDate . ', Page '.$this->PageNo() . "/{totalPages}",0,0,'R');
//    $pdf->Cell(0, 5, "PBX3 -  Page " . $pdf->PageNo() . "/{totalPages}", 0, 1);
}

}
