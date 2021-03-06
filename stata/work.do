/* 
 * Longitudinal Project -- BUILD data
 */

capture log close
clear all
use "long_buildv2.dta" , clear
log using longitudinal.log, text replace

***
*** Data Setup
***

* Generate treatment count and final post-test
* scores for use in "history" model.
sort sid semester
by sid: gen post_n = post[_N]
gen real_treat = treat if treatCat==2
egen tot_treat = sum(real_treat), by(sid)
egen kid_tag = tag(sid)

* Prepare and label categorical variables
quietly tab primlang, gen(lang_)
ren lang_6 english
drop lang_*
replace sed = sed - 1
lab val sed .
replace sped = sped - 1
lab val sped .
lab def grade 0 "K"
lab val grade grade
recode pared (3=1) (1 4 5 6=0) (2=.), gen(par_gs)
lab def par_gs 0 "< grad school" 1 "grad school"
lab val par_gs par_gs
lab def semester 7 "Fall 2014", modify

* exclude students in special education, since
* they receive different services
drop if sped == 1

* drop variables that we won't be using
drop merge11 real_treat
drop eng_prof school sped

egen MISS = rowmiss(post pre treat grade ///
					race female english par_gs sed)
saveold estimation_sample, replace

***
*** Data Exploration
***

* overall missingness patterns
misstable summ *, all

* longitudinal missingness patterns
xtset sid semester
xtdescribe


***
*** Exploratory Modeling
*** (using OLS to figure out which 
***  controls to include)
***

* Full model, with everything, and grade/treatment interaction
regress post pre c.treat##ib3.grade ///
			 i.race female english par_gs sed ///
			 if treatCat == 2 & MISS == 0
est store big

* Joint tests of categoricals, and interactions
testparm i.grade
testparm i.grade#c.treat
testparm i.race

* Reduced model, without race and grade/treatment interaction
regress post pre c.treat ib3.grade ///
			 female english par_gs sed ///
			 if treatCat == 2 & MISS == 0
est store mid

regress post pre if treatCat == 2 & MISS == 0
est store small

* Compare the results
est table small mid big, stats(rmse r2 aic bic)
*** Model "mid" is favored by AIC, with rmse
*** and R^2 almost identical to "big", but
*** with (a lot) fewer parameters

* We therefore proceed with the mean structure
* from "mid", with different covariance structures.




***
*** Longitudinal Modeling
***

* We try GEE with Exchangeable correlation
xtgee post pre c.treat ib3.grade ///
			 female english par_gs sed ///
			 if treatCat == 2 & MISS == 0, ///
			 corr(exch) 
est store model1a

* Robustifying the SE's makes a difference
xtgee post pre c.treat ib3.grade ///
			 female english par_gs sed ///
			 if treatCat == 2 & MISS == 0, ///
			 corr(exch) vce(robust)
est store model1b

* Random intercept model, in order to look at
* the proportion of residual variance
* at the person vs. occasion levels
xtreg post pre c.treat ib3.grade ///
			 female english par_gs sed ///
			 if treatCat == 2 & MISS == 0
est store model1c

* Robustifying the SE's makes some difference
xtreg post pre c.treat ib3.grade ///
			 female english par_gs sed ///
			 if treatCat == 2 & MISS == 0, ///
			 vce(robust)
est store model1d

* Compare the results
est table model1*, se p


***
*** Gain-Score Modeling
***
gen gain = post-pre
xtgee gain c.treat ib3.grade ///
			 female english par_gs sed ///
			 if treatCat == 2 & MISS == 0, ///
			 corr(exch) 
est store model2a
xtgee gain c.treat ib3.grade ///
			 female english par_gs sed ///
			 if treatCat == 2 & MISS == 0, ///
			 corr(exch) vce(robust)
est store model2b
xtreg gain c.treat ib3.grade ///
			 female english par_gs sed ///
			 if treatCat == 2 & MISS == 0
est store model2c

* Compare the results
est table model1* model2*
*** Modeling the gain score doesn't seem to help
*** The same coefficients are (non)significant
*** in both cases.  Gain score modeling is equivalent
*** to constraining the coeffcient of "pre" to 1.0
*** (it's already farily close), and imposing this 
*** constraint just biases the estimates of some of
*** the other coefficients that are correlated with
*** "pre".


***
*** Cross-Sectional (Historical) Modeling
***
regress post_n baseline ///
 			 if treatCat == 2 & MISS == 0 & kid_tag, ///
			 vce(robust)
est store history1

regress post_n baseline nSemester ///
 			 if treatCat == 2 & MISS == 0 & kid_tag, ///
			 vce(robust)
est store history2

regress post_n baseline tot_treat nSemester ///
			 female english par_gs sed ///
 			 if treatCat == 2 & MISS == 0 & kid_tag
est store history3a

regress post_n baseline tot_treat nSemester ///
			 female english par_gs sed ///
 			 if treatCat == 2 & MISS == 0 & kid_tag, ///
			 vce(robust)
est store history3b



* Compare SE's, significance, stats
est table history*, se p stats(rmse r2 aic bic)



*** 
*** Compare coefficients across our "best" models
***
est table model1b model1d history3b, se
mat list r(coef)
log close
