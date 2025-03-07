# /packages/intranet-payments/www/payment-action
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.


ad_page_contract {
    Purpose: Takes commands from the /intranet/payment/index
    page and deletes payments where marked

    @param return_url the url to return to
    @param group_id group id
    @author frank.bergmann@project-open.com
} {
    payment_id:multiple,optional
    { cost_id "" }
    { del "" }
    { add "" }
    return_url
}

set user_id [auth::require_login]
if {![im_permission $user_id add_payments]} {
    ad_return_complaint 1 "<li>[_ intranet-payments.lt_You_have_insufficient]"
    return
}

if {"" != $del} {

    foreach pid $payment_id {
	ns_log Notice "payment-action: deleting payments: $pid"
	db_dml delete_payment "delete from im_payments where payment_id=:pid"
    }
   
    # Update the cost_id amount
    im_cost_update_payments $cost_id

    ad_returnredirect $return_url
    return
}

if {"" != $add} {
    ns_log Notice "payment-action: add payment"
    ad_returnredirect [export_vars -base /intranet-payments/new {cost_id return_url}]
}

ad_return_complaint 1 "<li>[_ intranet-payments.No_command_specified]"
