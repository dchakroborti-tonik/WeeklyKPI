select *, (select max_current_dpd from `risk_credit_mis.loan_bucket_flow_report_core` where format_date('%Y%m%d',bucketDate) = format_date('%Y%m%d', cps.contact_date) and loanAccountNumber = cps.Loan_account_no) dpd 
from risk_credit_mis.collection_ptp_status cps
where date_trunc(contact_date, day) between '2023-03-13' and '2023-03-18'
and PTP_Due_Date is not null
;