/// Input information 
*** GOAL ***

taxinput country tax year_from year_to, source() status() ///
		currency() type() applies_to() exemption() ///
		lbounds() ubounds() mrates() toprate() note()
	


display "`c(current_time)' `c(current_date)'"

/// INFORMATION INPUT 

*** General 
global country = 
global currency = 

*** Tax-specific
global source = 
global tax = // Estate = 1, Inheritance = 2, Gift = 3
global status = // No = 0, Yes = 1
global type_tax = // Progressive by brackets = 1, Progressive by class = 2, Progressive continue = 3, Flat = 4, Lump-sum = 5
global first_year = 

*** Schedule-specific
global applies_to = 
global year_from = 
global year_to = 
global exemption = 
global top_rate =
global lbounds =
global ubounds = 
global mrates =
global note = 

********************************************************************************
********************************** LEGEND **************************************

// source
// country: ISO 2-digit code, capital letters
// currency: ISO code for the currency of the statutory information
// tax: inheritance, estate, gift
// status: Y, N
// kinship: child, parent, spouse, sibling. If it's none of this categories, set "other" and use the information for the highest tax rates


********************************************************************************
********************************** EXAMPLE *************************************

eigtinput country tax year_from year_to, ///
		source() status() currency() type() first_year() ///
		applies_to() exemption() toprate() lbounds() ubounds() mrates() note()
		

// Example Italian tax 1918-1919
// Inheritance tax progressive by class not due if the inheritance is <=100 Liras for linear relatives and spouse. 

eigtinput IT inheritance 1918 1919, source(ItalianTaxLaw_1918) status(1) ///
		currency(ITL) type(2) applies_to(1 2) exemption(0) ///
		lbounds(1 1 1 1 1 1 1 1 1 1) ///
		ubounds(1000 5000 25000 50000 100000 250000 500000 1000000 2000000) ///
		mrates(1 1.5 2 2 3 4 5 6 7 8 9)
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		