with yb as 
(select 
WkstartDate
,WkendDate
, sum(apc_wc_connected)apc_wc_connected
, sum(wccalled) wccalled  
, sum(bucket1contacted)bucket1contacted
, sum(bucketcallcontacted)bucketcallcontacted
, sum(bucket1normalized_greg)bucket1normalized_greg
, sum(bucket1normalized_denominator)bucket1normalized_denominator
, sum(bucket2normalized_greg)bucket2normalized_greg
, sum(bucket2normalized_denominator)bucket2normalized_denominator
, sum(kept_ptp)kept_ptp
, sum(ptp_received) ptp_received
, sum(bucket1ptppmt)bucket1ptppmt
, sum(bucket2ptppmt)bucket2ptppmt
from `dap_ds_poweruser_playground.collection_Monthly_kpi_v4` group by 1,2
),
fte as 
(select distinct agentFullName FROM
  `risk_credit_mis.call_attempt_history_gensys` g,
  yb
LEFT JOIN
  `dap_ds_poweruser_playground.campaignmaster` cm
ON
  UPPER(cm.Campaignname) = UPPER(g.campaignName)
WHERE
   DATE(g.callDatetime) BETWEEN DATE(yb.WkstartDate)  AND DATE(yb.WkendDate)
   and cm.reference in ('REM', 'COLL', 'WC')),
LUM as 
(select distinct loanAccountNumber from `prj-prod-dataplatform.risk_credit_mis.loan_master_table`, yb where flagDisbursement = 1 and date_trunc(disbursementDateTime, day) < yb.WkstartDate
and loanPaidStatus not in ('Written Off','Completed', 'Settled')),
aw as 
(select bucketDate, loanAccountNumber from `risk_credit_mis.loan_bucket_flow_report_core`, yb where coalesce(Max_current_DPD ,0) between 1 and 179 and date(bucketDate) = yb.WkstartDate and loanStatus not in ('Written Off','Completed', 'Settled'))
select min(WkstartDate)WkstartDate
,max(WkendDate)WkendDate
,sum(apc_wc_connected)/sum(wccalled) welcomecallcontactrate 
,sum(bucket1contacted)/ sum(bucketcallcontacted)Bucket1callcontactrate
, (sum(bucket1normalized_greg)/sum(bucket1normalized_denominator))bucket1normalized_greg_percentage
, (sum(bucket2normalized_greg)/sum(bucket2normalized_denominator))bucket2normalized_greg_percentage
,(select count(distinct agentFullName) from fte)FTE,
(select count(distinct loanAccountNumber) from LUM) total_accounts,
(select count(distinct loanAccountNumber) from aw) active_works
, (sum(kept_ptp)/sum(ptp_received)) kept_ptp
, (sum(bucket1ptppmt)+sum(bucket2ptppmt))totalmoneycollectedptp
from yb
where WkstartDate between '2023-01-01' and date(current_date())