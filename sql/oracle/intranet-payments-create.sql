-- /package/intranet-payments/sql/oracle/intranet-payments-create.sql
--
-- Payments module for Project/Open
--
-- (c) 2003 Frank Bergmann (fraber@fraber.de)
--
-- Defines:
--	im_payments			Payments
--	im_payments_audit		History of payment changes

------------------------------------------------------
-- Payments
--
-- Tracks the money coming into an invoice over time
--

create sequence im_payments_id_seq start with 10000;
create table im_payments (
	payment_id		integer not null 
				constraint im_payments_pk
				primary key,
	invoice_id		integer
				constraint im_payments_invoice
				references im_invoices,
				-- who pays?
	customer_id		integer not null
				constraint im_payments_customer
				references im_customers,
				-- who gets paid?
	provider_id		integer not null
				constraint im_payments_provider
				references im_customers,
	received_date		date,
	start_block		date 
				constraint im_payments_start_block
				references im_start_blocks,
	payment_type_id		integer
				constraint im_payments_type
				references im_categories,
	payment_status_id	integer
				constraint im_payments_status
				references im_categories,
	amount			number(12,2),
	currency		char(3) 
				constraint im_payments_currency
				references currency_codes(ISO),
	note			varchar(4000),
	last_modified   	date not null,
 	last_modifying_user	not null 
				constraint im_payments_mod_user
				references users,
	modified_ip_address	varchar(20) not null,
		-- Make sure we don't get duplicated entries for 
		-- whatever reason
		constraint im_payments_un
		unique (customer_id, invoice_id, provider_id, received_date, 
			start_block, payment_type_id, currency)
);

create table im_payments_audit (
	payment_id		integer,
	invoice_id		integer,
	customer_id		integer,
	provider_id		integer,
	received_date		date,
	start_block		date,
	payment_type_id		integer,
	payment_status_id	integer,
	amount			number(12,2),
	currency		char(3),
	note			varchar(4000),
	last_modified   	date not null,
 	last_modifying_user	integer,
	modified_ip_address	varchar(20) not null
);
create index im_proj_payments_aud_id_idx on im_payments_audit(payment_id);

create or replace trigger im_payments_audit_tr
	before update or delete on im_payments
	for each row
	begin
		insert into im_payments_audit (
			payment_id,
			invoice_id,
			customer_id,
			provider_id,
			received_date,
			start_block,
			payment_type_id,
			payment_status_id,
			amount,
			currency,
			note,
			last_modified,
			last_modifying_user,
			modified_ip_address
		) values (
			:old.payment_id,
			:old.invoice_id,
			:old.customer_id,
			:old.provider_id,
			:old.received_date,
			:old.start_block,
			:old.payment_type_id,
			:old.payment_status_id,
			:old.amount,
			:old.currency,
			:old.note,
			:old.last_modified,
			:old.last_modifying_user,
			:old.modified_ip_address
		);
end im_payments_audit_tr;
/
show errors


create or replace view im_payment_type as 
select category_id as payment_type_id, category as payment_type
from im_categories 
where category_type = 'Intranet Payment Type';

create or replace view im_invoice_payment_method as 
select 
	category_id as payment_method_id, 
	category as payment_method, 
	category_description as payment_description
from im_categories 
where category_type = 'Intranet Invoice Payment Method';


------------------------------------------------------
-- Add a "New Payments" item into the Invoices submenu
------------------------------------------------------

BEGIN
    im_component_plugin.del_module(module_name => 'intranet-payments');
    im_menu.del_module(module_name => 'intranet-payments');
END;
/
commit;

declare
        -- Menu IDs
        v_menu                  integer;
	v_invoices_menu		integer;
        -- Groups
        v_employees             integer;
        v_accounting            integer;
        v_senman                integer;
        v_customers             integer;
        v_freelancers           integer;
        v_proman                integer;
        v_admins                integer;
begin
    select group_id into v_admins from groups where group_name = 'P/O Admins';
    select group_id into v_senman from groups where group_name = 'Senior Managers';
    select group_id into v_accounting from groups where group_name = 'Accounting';
    select group_id into v_customers from groups where group_name = 'Customers';
    select group_id into v_freelancers from groups where group_name = 'Freelancers';

    select menu_id
    into v_invoices_menu
    from im_menus
    where label='invoices';

    delete from im_menus where package_name='intranet-payments';

    v_menu := im_menu.new (
	package_name =>	'intranet-payments',
	label =>	'payments_list',
	name =>		'Payments',
	url =>		'/intranet-payments/index',
	sort_order =>	20,
	parent_menu_id => v_invoices_menu
    );

    acs_permission.grant_permission(v_menu, v_admins, 'read');
    acs_permission.grant_permission(v_menu, v_senman, 'read');
    acs_permission.grant_permission(v_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_menu, v_customers, 'read');
    acs_permission.grant_permission(v_menu, v_freelancers, 'read');
    v_menu := im_menu.new (
	package_name =>	'intranet-payments',
	label =>	'payments_new',
	name =>		'New Payment',
	url =>		'/intranet-payments/new',
	sort_order =>	90,
	parent_menu_id => v_invoices_menu
    );

    acs_permission.grant_permission(v_menu, v_admins, 'read');
    acs_permission.grant_permission(v_menu, v_senman, 'read');
    acs_permission.grant_permission(v_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_menu, v_customers, 'read');
    acs_permission.grant_permission(v_menu, v_freelancers, 'read');
end;
/
commit;
	

------------------------------------------------------
-- Invoice Views
--
-- 30 invoice list
-- 31 invoice_new
insert into im_views (view_id, view_name, visible_for) 
values (32, 'payment_list', 'view_finance');

-- Payment List Page
--
delete from im_view_columns where column_id > 3200 and column_id < 3299;
--
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3201,32,NULL,'Payment #',
'"<A HREF=/intranet-payments/view?payment_id=$payment_id>$payment_id</A>"','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3203,32,NULL,'Invoice',
'"<A HREF=/intranet-invoices/view?invoice_id=$invoice_id>$invoice_nr</A>"','','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3205,32,NULL,'Client',
'"<A HREF=/intranet/customers/view?customer_id=$customer_id>$customer_name</A>"','','',5,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3207,32,NULL,'Received',
'$received_date','','',7,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3209,32,NULL,'Invoice Amount',
'$invoice_amount','','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3211,32,NULL,'Amount Paid',
'$amount $currency','','',11,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3213,32,NULL,'Status',
'$payment_status_id','','',13,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (3290,32,NULL,'Del',
'[if {1} {set ttt "<input type=checkbox name=del_payment value=$payment_id>"}]','','',99,'');

--
commit;


-- Payment Type
delete from im_categories where category_id >= 1000 and category_id < 1100;
INSERT INTO im_categories VALUES (1000,'Bank Transfer','','Intranet Payment Type',
'category','t','f');
INSERT INTO im_categories VALUES (1002,'Cheque','','Intranet Payment Type',
'category','t','f');
commit;
-- reserved until 1099
