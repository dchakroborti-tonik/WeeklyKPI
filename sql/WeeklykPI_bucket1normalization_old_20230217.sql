WITH
  MOBI AS (
  SELECT
    DISTINCT RIGHT(mobileNumber, 10) MOBILENUMBER
  FROM
    `risk_credit_mis.call_attempt_history_gensys`
  WHERE
    DATE_TRUNC(callDatetime, day) >= DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
    AND DATE_TRUNC(callDatetime, day) <= DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL 1 WEEK), WEEK(SUNDAY)) ),
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
weekstart as 
(SELECT distinct 
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
  case when coalesce(lbfrc.Max_current_DPD, 0) = 0 then 'Not Delinquent'
       when coalesce(lbfrc.Max_current_DPD, 0) between 1 and 30 then 'a. Bucket 1'
       when coalesce(lbfrc.Max_current_DPD, 0) between 31 and 60 then 'b Bucket 2'
       when coalesce(lbfrc.Max_current_DPD, 0) between 61 and 90 then 'c Bucket 3'
       else 'Over 90 DPD' end bucket,
    case when coalesce(lbfrc.Max_current_DPD, 0) = 0 then 0
       when coalesce(lbfrc.Max_current_DPD, 0) between 1 and 30 then 1
       when coalesce(lbfrc.Max_current_DPD, 0) between 31 and 60 then 2
       when coalesce(lbfrc.Max_current_DPD, 0) between 61 and 90 then 3
       else 90 end numbucket
FROM
  activeloans
  inner join `risk_credit_mis.loan_bucket_flow_report_core` lbfrc on lbfrc.loanAccountNumber = activeloans.loanAccountNumber
  where date(lbfrc.bucketDate) = DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
),
weekend as 
(SELECT distinct 
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
  case when coalesce(lbfrc.Max_current_DPD, 0) = 0 then 'Not Delinquent'
       when coalesce(lbfrc.Max_current_DPD, 0) between 1 and 30 then 'a. Bucket 1'
       when coalesce(lbfrc.Max_current_DPD, 0) between 31 and 60 then 'b Bucket 2'
       when coalesce(lbfrc.Max_current_DPD, 0) between 61 and 90 then 'c Bucket 3'
       else 'Over 90 DPD' end bucket,
    case when coalesce(lbfrc.Max_current_DPD, 0) = 0 then 0
       when coalesce(lbfrc.Max_current_DPD, 0) between 1 and 30 then 1
       when coalesce(lbfrc.Max_current_DPD, 0) between 31 and 60 then 2
       when coalesce(lbfrc.Max_current_DPD, 0) between 61 and 90 then 3
       else 90 end numbucket
FROM
  activeloans
  inner join `risk_credit_mis.loan_bucket_flow_report_core` lbfrc on lbfrc.loanAccountNumber = activeloans.loanAccountNumber
  where date(lbfrc.bucketDate) =  DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL 1 WEEK), WEEK(SUNDAY))
)
 select DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)) weekstartdate, DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL 1 WEEK), WEEK(SUNDAY)) weekenddate , weekstart.MOBILENUMBER, weekstart.loanAccountNumber, weekstart.bucket weekstartbucket, weekend.bucket weekendbucket, weekstart.numbucket weekstartnumbucket, weekend.numbucket weekendnumbucket
 , case when coalesce(weekstart.numbucket, 0) = 1 and coalesce(weekend.numbucket, 0) = 0 then weekstart.loanAccountNumber end Normalized
 from weekstart 
 left join weekend on weekstart.loanAccountNumber = weekend.loanAccountNumber