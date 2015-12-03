
if {![info exists title] && [info exists page_title]} { set title $page_title }
if {![info exists title] && [info exists doc(title)]} { set title $doc(title) }
if {![info exists title]} { set title [lang::message::lookup "" intranet-payments.Payments "Payments"] }