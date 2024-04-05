WITH
dt as 
(select date('2023-02-06') WkstartDate, date('2023-02-12') WkendDate)
,
  MOBI AS (
  SELECT DISTINCT
    date(dt.WkstartDate) WkstartDate,
    date(dt.WkendDate)WkendDate,
    RIGHT(mobileNumber, 10) MOBILENUMBER
  FROM
    `risk_credit_mis.call_attempt_history_gensys`, dt
  WHERE
    DATE_TRUNC(callDatetime, day) >= date(dt.WkstartDate)
    -- DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
    AND DATE_TRUNC(callDatetime, day) <= date(dt.WkendDate)
    --DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL 1 WEEK), WEEK(SUNDAY)) ),
  )
-- select MOBILENUMBER, count(MOBILENUMBER) from MOBI group by MOBILENUMBER having count(MOBILENUMBER) > 1;
  ,
  cd AS (
  SELECT
    customer_id,
    new_mobile_number,
    ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY change_date)rnk
  FROM
    `risk_credit_mis.customer_contact_details`
  WHERE
    ACTIVE = 'Y')
 ,custidentify AS (
  SELECT
    *
  FROM
    MOBI
  LEFT JOIN
    cd
  ON
    RIGHT(cd.new_mobile_number, 10) = MOBI.MOBILENUMBER
  WHERE
    cd.customer_id IS NOT NULL )
  -- select * from custidentify;
  ,
  activeloans AS (
  SELECT
    custidentify.WkstartDate,
    custidentify.WkendDate,
    custidentify.MOBILENUMBER,
    custidentify.customer_id,
    lmt.digitalLoanAccountId,
    lmt.loanAccountNumber,
    lmt.applicationStatus,
    lmt.disbursementDateTime,
    lmt.flagDisbursement,
    lmt.currentDelinquency,
    lmt.loanType,
  FROM
    custidentify
  INNER JOIN
    `risk_credit_mis.loan_master_table` lmt
  ON
    lmt.customerId = custidentify.customer_id
  WHERE
    lmt.loanAccountNumber IN (
    SELECT
      loanAccountNumber
    FROM
      `risk_credit_mis.loan_master_table`
    WHERE
      (loanPaidStatus LIKE '%Nor%'
        OR loanPaidStatus LIKE '%In%'
        OR COALESCE(loanPaidStatus, 'NA') LIKE 'NA')) )
      -- select loanAccountNumber , count(loanAccountNumber) from activeloans group by loanAccountNumber having count(loanAccountNumber) > 1;  
      select * from activeloans where loanAccountNumber = '60815684630018'
    
  
