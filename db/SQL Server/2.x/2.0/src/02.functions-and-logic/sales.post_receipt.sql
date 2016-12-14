﻿IF OBJECT_ID('sales.post_receipt') IS NOT NULL
DROP PROCEDURE sales.post_receipt;

GO

CREATE PROCEDURE sales.post_receipt
(
    @user_id                                    integer, 
    @office_id                                  integer, 
    @login_id                                   bigint,
    
    @customer_id                                integer,
    @currency_code                              national character varying(12), 
    @exchange_rate_debit                        dbo.decimal_strict, 

    @exchange_rate_credit                       dbo.decimal_strict,
    @reference_number                           national character varying(24), 
    @statement_reference                        national character varying(2000), 

    @cost_center_id                             integer,
    @cash_account_id                            integer,
    @cash_repository_id                         integer,

    @value_date                                 date,
    @book_date                                  date,
    @receipt_amount                             dbo.money_strict,

    @tender                                     dbo.money_strict2,
    @change                                     dbo.money_strict2,
    @check_amount                               dbo.money_strict2,

    @check_bank_name                            national character varying(1000),
    @check_number                               national character varying(100),
    @check_date                                 date,

    @gift_card_number                           national character varying(100),
    @store_id                                   integer DEFAULT NULL,
    @cascading_tran_id                          bigint DEFAULT NULL
)
AS
BEGIN
    DECLARE @book                               national character varying(50);
    DECLARE @transaction_master_id              bigint;
    DECLARE @base_currency_code                 national character varying(12);
    DECLARE @local_currency_code                national character varying(12);
    DECLARE @customer_account_id                integer;
    DECLARE @debit                              dbo.money_strict2;
    DECLARE @credit                             dbo.money_strict2;
    DECLARE @lc_debit                           dbo.money_strict2;
    DECLARE @lc_credit                          dbo.money_strict2;
    DECLARE @is_cash                            bit;
    DECLARE @gift_card_id                       integer;
    DECLARE @receivable_account_id              integer;

    IF NOT finance.can_post_transaction(@login_id, @user_id, @office_id, @book, @value_date)
    BEGIN
        RETURN 0;
    END;

    IF(@cash_repository_id > 0 AND @cash_account_id > 0)
    BEGIN
        @is_cash                            = 1;
    END;

    @receivable_account_id                  = sales.get_receivable_account_for_check_receipts(@store_id);
    @gift_card_id                           = sales.get_gift_card_id_by_gift_card_number(@gift_card_number);
    @customer_account_id                    = inventory.get_account_id_by_customer_id(@customer_id);    
    @local_currency_code                    = core.get_currency_code_by_office_id(@office_id);
    @base_currency_code                     = inventory.get_currency_code_by_customer_id(@customer_id);


    IF(@local_currency_code = @currency_code AND @exchange_rate_debit != 1)
    BEGIN
        RAISERROR('Invalid exchange rate.', 10, 1);
    END;

    IF(@base_currency_code = @currency_code AND @exchange_rate_credit != 1)
    BEGIN
        RAISERROR('Invalid exchange rate.', 10, 1);
    END;

    
    IF(@tender >= @receipt_amount)
    BEGIN
        @transaction_master_id              = sales.post_cash_receipt(@user_id, @office_id, @login_id, @customer_id, @customer_account_id, @currency_code, @local_currency_code, @base_currency_code, @exchange_rate_debit, @exchange_rate_credit, @reference_number, @statement_reference, @cost_center_id, @cash_account_id, @cash_repository_id, @value_date, @book_date, @receipt_amount, @tender, @change, @cascading_tran_id);
    END
    ELSE IF(@check_amount >= @receipt_amount)
    BEGIN
        @transaction_master_id              = sales.post_check_receipt(@user_id, @office_id, @login_id, @customer_id, @customer_account_id, @receivable_account_id, @currency_code, @local_currency_code, @base_currency_code, @exchange_rate_debit, @exchange_rate_credit, @reference_number, @statement_reference, @cost_center_id, @value_date, @book_date, @check_amount, @check_bank_name, @check_number, @check_date, @cascading_tran_id);
    END
    ELSE IF(@gift_card_id > 0)
    BEGIN
        @transaction_master_id              = sales.post_receipt_by_gift_card(@user_id, @office_id, @login_id, @customer_id, @customer_account_id, @currency_code, @local_currency_code, @base_currency_code, @exchange_rate_debit, @exchange_rate_credit, @reference_number, @statement_reference, @cost_center_id, @value_date, @book_date, @gift_card_id, @gift_card_number, @receipt_amount, @cascading_tran_id);
    END
    ELSE
    BEGIN
        RAISERROR('Cannot post receipt. Please enter the tender amount.', 10, 1);
    END;

    
    EXECUTE finance.auto_verify @transaction_master_id, @office_id;
    EXECUTE sales.settle_customer_due @customer_id, @office_id;
    SELECT @transaction_master_id;
END;




--SELECT * FROM sales.post_receipt(1, 1, 1,inventory.get_customer_id_by_customer_code('APP'), 'USD', 1, 1, '', '', 1, 1, 1, '1-1-2020', '1-1-2020', 100, 0, 1000, '', '', null, '', null);
--SELECT * FROM sales.post_receipt(1,1,1,inventory.get_customer_id_by_customer_code('DEF'),'USD',1,1,'','', 1, 1, 1, '1-1-2020', '1-1-2020', 2000, 0, 0, 0, '', '', null, '123456', 1, null);


GO