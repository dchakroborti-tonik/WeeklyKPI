-- create table `dap_ds_poweruser_playground.collectionkpifirstbucketnormalization` as 
-- insert into `dap_ds_poweruser_playground.collectionkpifirstbucketnormalization`
WITH
  dt AS (
  SELECT
    DATE('2023-02-13') WkstartDate,
    DATE('2023-02-19') WkendDate),
  MOBI AS (
  SELECT
    DISTINCT DATE(dt.WkstartDate) WkstartDate,
    DATE(dt.WkendDate)WkendDate,
    RIGHT(mobileNumber, 10) MOBILENUMBER
  FROM
    `risk_credit_mis.call_attempt_history_gensys`,
    dt
  WHERE
    DATE_TRUNC(callDatetime, day) >= DATE(dt.WkstartDate) -- DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
    AND DATE_TRUNC(callDatetime, day) <= DATE(dt.WkendDate) --DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL 1 WEEK), WEEK(SUNDAY)) ),
    ) ,
  cd AS (
  SELECT
    customer_id,
    new_mobile_number,
    ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY change_date)rnk
  FROM
    `risk_credit_mis.customer_contact_details`
  WHERE
    ACTIVE = 'Y'),
  custidentify AS (
  SELECT
    *
  FROM
    MOBI
  LEFT JOIN
    cd
  ON
    RIGHT(cd.new_mobile_number, 10) = MOBI.MOBILENUMBER
  WHERE
    cd.customer_id IS NOT NULL ),
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
        OR COALESCE(loanPaidStatus, 'NA') LIKE 'NA')) ),
  weekstart AS (
  SELECT
    DISTINCT DATE(dt.WkstartDate)WkstartDate,
    DATE(dt.WkendDate)WkendDate,
    activeloans.MOBILENUMBER,
    activeloans.customer_id,
    activeloans.digitalLoanAccountId,
    activeloans.loanAccountNumber,
    activeloans.applicationStatus,
    activeloans.disbursementDateTime,
    activeloans.flagDisbursement,
    activeloans.currentDelinquency,
    activeloans.loanType,
    lbfrc.bucketDate,
    lbfrc.firstDueDate,
    lbfrc.Max_current_DPD,
    CASE
      WHEN COALESCE(lbfrc.Max_current_DPD, 0) = 0 THEN 'Not Delinquent'
      WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 1
    AND 30 THEN 'a. Bucket 1'
      WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 31 AND 60 THEN 'b Bucket 2'
      WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 61
    AND 90 THEN 'c Bucket 3'
    ELSE
    'Over 90 DPD'
  END
    bucket,
    CASE
      WHEN COALESCE(lbfrc.Max_current_DPD, 0) = 0 THEN 0
      WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 1
    AND 30 THEN 1
      WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 31 AND 60 THEN 2
      WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 61
    AND 90 THEN 3
    ELSE
    90
  END
    numbucket
  FROM
    activeloans,
    dt
  INNER JOIN
    `risk_credit_mis.loan_bucket_flow_report_core` lbfrc
  ON
    lbfrc.loanAccountNumber = activeloans.loanAccountNumber
    AND DATE(lbfrc.bucketDate) = DATE(activeloans.WkstartDate) ),
    weekend AS (
    SELECT
      DISTINCT DATE(dt.WkstartDate)WkstartDate,
      DATE(dt.WkendDate)WkendDate,
      activeloans.MOBILENUMBER,
      activeloans.customer_id,
      activeloans.digitalLoanAccountId,
      activeloans.loanAccountNumber,
      activeloans.applicationStatus,
      activeloans.disbursementDateTime,
      activeloans.flagDisbursement,
      activeloans.currentDelinquency,
      activeloans.loanType,
      lbfrc.bucketDate,
      lbfrc.firstDueDate,
      lbfrc.Max_current_DPD,
      CASE
        WHEN COALESCE(lbfrc.Max_current_DPD, 0) = 0 THEN 'Not Delinquent'
        WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 1
      AND 30 THEN 'a. Bucket 1'
        WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 31 AND 60 THEN 'b Bucket 2'
        WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 61
      AND 90 THEN 'c Bucket 3'
      ELSE
      'Over 90 DPD'
    END
      bucket,
      CASE
        WHEN COALESCE(lbfrc.Max_current_DPD, 0) = 0 THEN 0
        WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 1
      AND 30 THEN 1
        WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 31 AND 60 THEN 2
        WHEN COALESCE(lbfrc.Max_current_DPD, 0) BETWEEN 61
      AND 90 THEN 3
      ELSE
      90
    END
      numbucket
    FROM
      activeloans,
      dt
    INNER JOIN
      `risk_credit_mis.loan_bucket_flow_report_core` lbfrc
    ON
      lbfrc.loanAccountNumber = activeloans.loanAccountNumber
      AND DATE(lbfrc.bucketDate) = DATE(activeloans.WkendDate) --
    WHERE
      DATE(lbfrc.bucketDate) = DATE(dt.WkendDate) ),
      base AS (
      SELECT
        DATE(dt.WkstartDate)weekstartdate,
        DATE(dt.WkendDate)weekenddate ,
        weekstart.MOBILENUMBER,
        weekstart.loanAccountNumber,
        weekstart.bucket weekstartbucket,
        weekend.bucket weekendbucket,
        weekstart.numbucket weekstartnumbucket,
        weekend.numbucket weekendnumbucket,
        CASE
          WHEN COALESCE(weekstart.numbucket, 0) = 1 AND COALESCE(weekend.numbucket, 0) = 0 THEN weekstart.loanAccountNumber
      END
        Normalized
      FROM
        weekstart,
        dt
      LEFT JOIN
        weekend
      ON
        weekstart.loanAccountNumber = weekend.loanAccountNumber
        AND weekstart.WkstartDate = weekend.WkstartDate
        AND weekstart.WkendDate = weekend.WkendDate )
    SELECT
      *
    FROM
      base;