#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma modulename=DE_NewDudko
#include "DE_Filtering"
#include "DTE_Dudko"
#include "DE_Correctrupture"
#include "DE_OverlapRamps"

Static Function/C CorrectionBasedonRequest(ForceWave,Shifted)
	wave ForceWave
	variable Shifted //1 Use the value from allowing the sep to change, 0 means use the value for unchanged
	
	variable UsedFOff=str2num(stringbykey("UsedAlignmentFShift", note(ForceWave),":","\r"))
	variable UsedSOff=str2num(stringbykey("UsedAlignmentSShift", note(ForceWave),":","\r"))
		variable AltFOff=str2num(stringbykey("AltAlignmentFShift", note(ForceWave),":","\r"))
	variable AltSOff=str2num(stringbykey("AltAlignmentSShift", note(ForceWave),":","\r"))
	variable unshiftedF,unshiftedS,shiftedF,shiftedS,DesiredF,DesiredS
	if(abs(UsedSOff)<1e-13)
		unshiftedF=UsedFOff
		unshiftedS=UsedSOff
		shiftedF=AltFOff
		shiftedS=AltSOff
		
		else
		unshiftedF=AltFOff
		unshiftedS=AltSOff
		shiftedF=UsedFOff
		shiftedS=UsedSOff
		
	endif
	
	if(Shifted==0)
		DesiredF=unshiftedF
		DesiredS=unshiftedS

	else
		DesiredF=shiftedF
		DesiredS=shiftedS
	endif
	return cmplx(DesiredF-UsedFOff,DesiredS-UsedSOff)
end

Static Function FindRuptureForcesbyTimebyIndex(n,WLCParms,ForceWave,Sepwave,StateWave,FoldingForce,UnfoldingForce,[Diagnostic])
	variable n,Diagnostic
	wave WLCParms,StateWave,Sepwave,ForceWave,FoldingForce,UnfoldingForce
	variable FOldedLC=WLCPArms[0]
	variable UnfoldedLC=WLCPArms[1]
	Variable FOrceOff=WLCPArms[2]
	variable SepOff=WLCPArms[3]
	
	make/free/n=(dimsize(Statewave,0)) Points,RupForce,Type,Trace
	Points=Statewave[p][0]
	RupForce=-Statewave[p][1]
	Type=Statewave[p][2]
	Trace=Statewave[p][3]
	
	Extract/INDX/Free Points, LocalIndex, Trace==n
	make/free/n=(numpnts(LocalIndex)+1) LocalPoints,LocalType,LocalTrace
	LocalPoints[]=Points[LocalIndex[0]+p][0]
	LocalType[]=Type[LocalIndex[0]+p][2]
	LocalTrace[]=Trace[LocalIndex[0]+p][2]
	FindValue/V=-2/T=.1 LocalType
	variable turnaround=v_value
	duplicate/o/R=[LocalPoints[0],LocalPoints[turnaround]] SepWave, FirstSepWave,FirstSepWaveFolded,FirstSepWaveUnfolded
	duplicate/o/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-2]] SepWave, SecondSepWave,SecondSepWaveFolded,SecondSepWaveUnfolded
	duplicate/o/R=[LocalPoints[0],LocalPoints[turnaround]] ForceWave, FirstForceWave
	duplicate/o/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-1]] ForceWave, SecondForceWave

	GenerateSepLine(ForceWave,SepWave,StateWave,n,0,0,FirstSepWaveUnfolded)
	GenerateSepLine(ForceWave,SepWave,StateWave,n,0,1,FirstSepWaveFolded)
	GenerateSepLine(ForceWave,SepWave,StateWave,n,1,0,SecondSepWaveUnfolded)
	GenerateSepLine(ForceWave,SepWave,StateWave,n,1,1,SecondSepWaveFolded)
	variable m,CurrentTime,CurrentSep,CurrentForce
	make/free/n=0 UnfoldingFree,FoldingFree
	for(m=1;m<turnaround;m+=1)
			if(LocalType[m]==-1)//unfolding
			Insertpoints numpnts(UnfoldingFree),1, UnfoldingFree
			CurrentTime=pnt2x(Sepwave,LocalPoints[m])

			CurrentSep=FirstSepWaveFolded(CurrentTime)
			CurrentForce=WLC(CurrentSep-SepOff,-.4e-9,FOldedLC,298)-FOrceOff
			UnfoldingFree[numpnts(UnfoldingFree)-1]=CurrentForce
		elseif(LocalType[m]==1)//folding
			Insertpoints numpnts(FoldingFree),1, FoldingFree
			CurrentTime=pnt2x(Sepwave,LocalPoints[m])
			CurrentSep=FirstSepWaveFolded(CurrentTime)
			CurrentForce=WLC(CurrentSep-SepOff,-.4e-9,UnFOldedLC,298)-FOrceOff

			FoldingFree[numpnts(FoldingFree)-1]=CurrentForce

		endif
	endfor
	
	for(m=turnaround+1;m<numpnts(LocalPoints)-2;m+=1)
		if(LocalType[m]==-1)//unfolding
			Insertpoints numpnts(UnfoldingFree),1, UnfoldingFree
			CurrentTime=pnt2x(Sepwave,LocalPoints[m])
			CurrentSep=SecondSepWaveFolded(CurrentTime)
			CurrentForce=WLC(CurrentSep-SepOff,-.4e-9,FOldedLC,298)-FOrceOff
			UnfoldingFree[numpnts(UnfoldingFree)-1]=CurrentForce
		elseif(LocalType[m]==1)//folding
			Insertpoints numpnts(FoldingFree),1, FoldingFree
			CurrentTime=pnt2x(Sepwave,LocalPoints[m])
			CurrentSep=SecondSepWaveFolded(CurrentTime)
			CurrentForce=WLC(CurrentSep-SepOff,-.4e-9,UnFOldedLC,298)-FOrceOff
			FoldingFree[numpnts(FoldingFree)-1]=CurrentForce

		endif
	endfor

	duplicate/o FoldingFree FoldingForce
	duplicate/o unFoldingFree  UnfoldingForce
//	variable FoldedExt= DE_WLC#ReturnExtentionatForce(Force+FOrceOff,-.4e-9,FOldedLC,298)+SepOff
//	variable UnFoldedExt= DE_WLC#ReturnExtentionatForce(Force+FOrceOff,-.4e-9,UnFOldedLC,298)+SepOff
//	variable FoldedTime1,FoldedTime2,UnfoldedTime1,UnfoldedTime2,foldedcounts1,unfoldedcounts1,foldedcounts2,unfoldedcounts2
//	foldedcounts1=1
//	unfoldedcounts2=1
//
//	//print FoldedExt;print UnFoldedExt
//
//
////	CurveFit/Q line FirstSepWave[0,LocalPoints[1]-LocalPoints[0]] 
////	wave W_coef
////	FirstSepWaveFolded=W_coef[0]+W_coef[1]*x
////	CurveFit/Q line FirstSepWave[LocalPoints[turnaround-1]-LocalPoints[0],LocalPoints[turnaround]-LocalPoints[0]] 
////	FirstSepWaveUnFolded=W_coef[0]+W_coef[1]*x
////	CurveFit/Q line SecondSepWave[0,LocalPoints[turnaround+1]-LocalPoints[turnaround]] 
////	SecondSepWaveFolded=W_coef[0]+W_coef[1]*x
////	CurveFit/Q line SecondSepWave[LocalPoints[numpnts(LocalPoints)-3]-LocalPoints[turnaround],LocalPoints[numpnts(LocalPoints)-2]-LocalPoints[turnaround]] 
////	SecondSepWaveUnFolded=W_coef[0]+W_coef[1]*x
//
//	if(wavemin(FirstSepWaveFolded)>FoldedExt)
//		FoldedTime1=pnt2x(Sepwave,LocalPoints[0])
//	elseif(wavemax(FirstSepWaveFolded)<FoldedExt)
//		FoldedTime1=pnt2x(Sepwave,LocalPoints[turnaround])
//	else
//		FindLevels/Q FirstSepWaveFolded FoldedExt
//		wave W_FindLevels
//		FoldedTime1 = mean(W_FindLevels)//-pnt2x(FirstSepWave,0)
//	endif
//	
//	if(wavemax(SecondSepWaveFolded)<FoldedExt)
//		FoldedTime2=pnt2x(Sepwave,LocalPoints[turnaround])
//	elseif(wavemin(SecondSepWaveFolded)>FoldedExt)
//			FoldedTime2=pnt2x(Sepwave,LocalPoints[numpnts(LocalPoints)-2])
//	else
//		FindLevels/Q SecondSepWaveFolded FoldedExt
//		FoldedTime2= mean(W_FindLevels)//-pnt2x(FirstSepWave,0)
//	endif
//	
//	if(wavemin(FirstSepWaveUnFolded)>unFoldedExt)
//			unFoldedTime1=pnt2x(Sepwave,LocalPoints[0])
//	elseif(wavemax(FirstSepWaveUnFolded)<unFoldedExt)
//			unFoldedTime1=pnt2x(Sepwave,LocalPoints[turnaround])
//	else
//		FindLevels/Q FirstSepWaveUnFolded unFoldedExt
//		wave W_FindLevels
//		UnfoldedTime1= mean(W_FindLevels)//-pnt2x(FirstSepWave,0)
//	endif
//	
//	if(wavemax(SecondSepWaveUnFolded)<unFoldedExt)
//				unFoldedTime2=pnt2x(Sepwave,LocalPoints[turnaround])
//	elseif(wavemin(SecondSepWaveUnFolded)>unFoldedExt)
//				unFoldedTime2=pnt2x(Sepwave,LocalPoints[numpnts(LocalPoints)-2])
//	else
//		FindLevels/Q SecondSepWaveUnFolded unFoldedExt
//		UnfoldedTime2= mean(W_FindLevels)//-pnt2x(FirstSepWave,0)
//	endif
//
//	variable m

//	wave W_Sigma
//	killwaves/Z w_coef, W_FindLevels,w_sigma
//	if(!ParamisDefault(Diagnostic))
//		make/o/n=(100) WFoldedExt,WUnfoldedExt
//		WFoldedExt=FoldedExt
//		WUnfoldedExt=UnFoldedExt
//		duplicate/o/r=[LocalPoints[0],LocalPoints[numpnts(localpoints)-1]] ForceWave ForceOut
//		duplicate/o/r=[LocalPoints[0],LocalPoints[numpnts(localpoints)-1]] SepWave sepOut
//		SetScale/I x pnt2x(FirstSepWave,0),pnt2x(SecondSepWave,numpnts(SecondSepWave)-1),"", WUnfoldedExt,WFoldedExt
//		duplicate/free/R=[LocalPoints[0],LocalPoints[numpnts(localpoints)-1]] SepWave, TotalSep
//		duplicate/o LocalPoints LocalPointsOut,LocalSepsOut
//		variable UG=LocalPointsOut[0]
//		LocalPointsOut-=UG
//		LocalPointsOut=pnt2x(TotalSep,(LocalPointsOut))
//		LocalSepsOut=TotalSep(LocalPointsOut)
//	endif
//	return cmplx(foldedcounts1+foldedcounts2,unfoldedcounts1+unfoldedcounts2)
//	
end

Static Function/C FindStatesbyTimebyIndex(Force,n,WLCParms,ForceWave,Sepwave,StateWave,[Diagnostic])
	variable n,Force,Diagnostic
	wave WLCParms,StateWave,Sepwave,ForceWave
	variable FOldedLC=WLCPArms[0]
	variable UnfoldedLC=WLCPArms[1]
	Variable FOrceOff=WLCPArms[2]
	variable SepOff=WLCPArms[3]
	variable FoldedExt= DE_WLC#ReturnExtentionatForce(Force+FOrceOff,-.4e-9,FOldedLC,298)+SepOff
	variable UnFoldedExt= DE_WLC#ReturnExtentionatForce(Force+FOrceOff,-.4e-9,UnFOldedLC,298)+SepOff
	variable FoldedTime1,FoldedTime2,UnfoldedTime1,UnfoldedTime2,foldedcounts1,unfoldedcounts1,foldedcounts2,unfoldedcounts2
	foldedcounts1=1
	unfoldedcounts2=1

	//print FoldedExt;print UnFoldedExt
	make/free/n=(dimsize(Statewave,0)) Points,RupForce,Type,Trace
	Points=Statewave[p][0]
	RupForce=-Statewave[p][1]
	Type=Statewave[p][2]
	Trace=Statewave[p][3]
	
	Extract/INDX/Free Points, LocalIndex, Trace==n
	make/free/n=(numpnts(LocalIndex)+1) LocalPoints,LocalType,LocalTrace
	LocalPoints[]=Points[LocalIndex[0]+p][0]
	LocalType[]=Type[LocalIndex[0]+p][2]
	LocalTrace[]=Trace[LocalIndex[0]+p][2]
	FindValue/V=-2/T=.1 LocalType
	variable turnaround=v_value
	
	duplicate/o/R=[LocalPoints[0],LocalPoints[turnaround]] SepWave, FirstSepWave,FirstSepWaveFolded,FirstSepWaveUnfolded
	duplicate/o/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-2]] SepWave, SecondSepWave,SecondSepWaveFolded,SecondSepWaveUnfolded
	duplicate/o/R=[LocalPoints[0],LocalPoints[turnaround]] ForceWave, FirstForceWave
	duplicate/o/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-1]] ForceWave, SecondForceWave

	GenerateSepLine(ForceWave,SepWave,StateWave,n,0,0,FirstSepWaveUnfolded)
	GenerateSepLine(ForceWave,SepWave,StateWave,n,0,1,FirstSepWaveFolded)
	GenerateSepLine(ForceWave,SepWave,StateWave,n,1,0,SecondSepWaveUnfolded)
	GenerateSepLine(ForceWave,SepWave,StateWave,n,1,1,SecondSepWaveFolded)


//	CurveFit/Q line FirstSepWave[0,LocalPoints[1]-LocalPoints[0]] 
//	wave W_coef
//	FirstSepWaveFolded=W_coef[0]+W_coef[1]*x
//	CurveFit/Q line FirstSepWave[LocalPoints[turnaround-1]-LocalPoints[0],LocalPoints[turnaround]-LocalPoints[0]] 
//	FirstSepWaveUnFolded=W_coef[0]+W_coef[1]*x
//	CurveFit/Q line SecondSepWave[0,LocalPoints[turnaround+1]-LocalPoints[turnaround]] 
//	SecondSepWaveFolded=W_coef[0]+W_coef[1]*x
//	CurveFit/Q line SecondSepWave[LocalPoints[numpnts(LocalPoints)-3]-LocalPoints[turnaround],LocalPoints[numpnts(LocalPoints)-2]-LocalPoints[turnaround]] 
//	SecondSepWaveUnFolded=W_coef[0]+W_coef[1]*x

	if(wavemin(FirstSepWaveFolded)>FoldedExt)
		FoldedTime1=pnt2x(Sepwave,LocalPoints[0])
	elseif(wavemax(FirstSepWaveFolded)<FoldedExt)
		FoldedTime1=pnt2x(Sepwave,LocalPoints[turnaround])
	else
		FindLevels/Q FirstSepWaveFolded FoldedExt
		wave W_FindLevels
		FoldedTime1 = mean(W_FindLevels)//-pnt2x(FirstSepWave,0)
	endif
	
	if(wavemax(SecondSepWaveFolded)<FoldedExt)
		FoldedTime2=pnt2x(Sepwave,LocalPoints[turnaround])
	elseif(wavemin(SecondSepWaveFolded)>FoldedExt)
			FoldedTime2=pnt2x(Sepwave,LocalPoints[numpnts(LocalPoints)-2])
	else
		FindLevels/Q SecondSepWaveFolded FoldedExt
		FoldedTime2= mean(W_FindLevels)//-pnt2x(FirstSepWave,0)
	endif
	
	if(wavemin(FirstSepWaveUnFolded)>unFoldedExt)
			unFoldedTime1=pnt2x(Sepwave,LocalPoints[0])
	elseif(wavemax(FirstSepWaveUnFolded)<unFoldedExt)
			unFoldedTime1=pnt2x(Sepwave,LocalPoints[turnaround])
	else
		FindLevels/Q FirstSepWaveUnFolded unFoldedExt
		wave W_FindLevels
		UnfoldedTime1= mean(W_FindLevels)//-pnt2x(FirstSepWave,0)
	endif
	
	if(wavemax(SecondSepWaveUnFolded)<unFoldedExt)
				unFoldedTime2=pnt2x(Sepwave,LocalPoints[turnaround])
	elseif(wavemin(SecondSepWaveUnFolded)>unFoldedExt)
				unFoldedTime2=pnt2x(Sepwave,LocalPoints[numpnts(LocalPoints)-2])
	else
		FindLevels/Q SecondSepWaveUnFolded unFoldedExt
		UnfoldedTime2= mean(W_FindLevels)//-pnt2x(FirstSepWave,0)
	endif

	variable m
	for(m=1;m<turnaround;m+=1)

		if(pnt2x(Sepwave,LocalPoints[m])<FoldedTime1)
			foldedcounts1+= LocalType[m] 

		endif
		if(pnt2x(Sepwave,LocalPoints[m])<unFoldedTime1)
			unfoldedcounts1-= LocalType[m] 

		endif
	endfor
	
	for(m=turnaround+1;m<numpnts(LocalPoints)-2;m+=1)

		if(pnt2x(Sepwave,LocalPoints[m])<FoldedTime2)
			foldedcounts2+= LocalType[m] 


		endif
		if(pnt2x(Sepwave,LocalPoints[m])<unFoldedTime2)
			unfoldedcounts2-= LocalType[m] 

		endif
	endfor
	wave W_Sigma
	killwaves/Z w_coef, W_FindLevels,w_sigma
	if(!ParamisDefault(Diagnostic))
		make/o/n=(100) WFoldedExt,WUnfoldedExt
		WFoldedExt=FoldedExt
		WUnfoldedExt=UnFoldedExt
		duplicate/o/r=[LocalPoints[0],LocalPoints[numpnts(localpoints)-1]] ForceWave ForceOut
		duplicate/o/r=[LocalPoints[0],LocalPoints[numpnts(localpoints)-1]] SepWave sepOut
		SetScale/I x pnt2x(FirstSepWave,0),pnt2x(SecondSepWave,numpnts(SecondSepWave)-1),"", WUnfoldedExt,WFoldedExt
		duplicate/free/R=[LocalPoints[0],LocalPoints[numpnts(localpoints)-1]] SepWave, TotalSep
		duplicate/o LocalPoints LocalPointsOut,LocalSepsOut
		variable UG=LocalPointsOut[0]
		LocalPointsOut-=UG
		LocalPointsOut=pnt2x(TotalSep,(LocalPointsOut))
		LocalSepsOut=TotalSep(LocalPointsOut)
	endif
	return cmplx(foldedcounts1+foldedcounts2,unfoldedcounts1+unfoldedcounts2)
	
end


Static Function AccumulateAllRuptures(StateWave,ForceWave,AccState,FoldedAcc,Unfoldedacc,Accum)

	wave StateWave,ForceWave,FoldedAcc,Unfoldedacc,AccState
	variable Accum
	Struct Forcewave PrimaryName

	//DE_Naming#WavetoStruc(nameofwave(Forcewave),PrimaryName)
	DE_Naming#RealWavetoStruc(Forcewave,PrimaryName)

	make/free/n=(dimsize(StateWave,0)) Points,Types,MatchPoints
	Points=Statewave[p][0]
	Types=Statewave[p][2] 
	Extract/Free Points, PUnfold, Types==-1
	Extract/Free/INDX Points, UnPoints, Types==-1

	Extract/Free Points, PRefold, Types==1
	Extract/Free/INDX Points, RePoints, Types==1

	Duplicate/free PUnfold FUnfold,RampUnfOld
	Duplicate/free PRefold FRefold,RampRefOld
	
	variable forceoff,sepoff
	controlinfo de_dudko_check0

	variable/C Offsets=CorrectionBasedonRequest(ForceWave,V_value)
	forceoff=real(Offsets)
	sepoff=imag(Offsets)

//	controlinfo de_dudko_check0
//	if(V_value==1)
//	controlinfo de_Dudko_setvar3
//	forceoff=ChangeTheForce(ForceWave,v_value)
//	else
//		forceoff=0
//
//	endif
//	
//		controlinfo de_dudko_check1
//	if(V_value==1)
//		controlinfo de_Dudko_setvar4
//
//	sepoff=de_NEWdUDKO#ChangeTheSep(ForceWave,v_value)
//	else
//		sepoff=0
//
//	endif
	//print forceoff
	//print sepoff
	FUnfold=ForceWave[PUnfold]+forceoff
	RampUnfOld=StateWave[UnPoints[p]][3]
	FRefold=ForceWave[PRefold]+forceoff
	RampRefOld=StateWave[RePoints[p]][3]
	make/free/n=(dimsize(FUnfold,0),4) UnFoldCollect
	UnFoldCollect[][0]=PrimaryName.vnum
	UnFoldCollect[][1]=RampUnfOld[p]
	UnFoldCollect[][2]=PUnfold[p]
	UnFoldCollect[][3]=FUnfold[p]
	make/free/n=(dimsize(FUnfold,0),4) FoldCollect
	FoldCollect[][0]=PrimaryName.vnum
	FoldCollect[][1]=RampRefOld[p]
	FoldCollect[][2]=PRefold[p]
	FoldCollect[][3]=FRefold[p]
	
	if(numpnts(FoldedAcc)==0||numpnts(Unfoldedacc)==0)
	print "Empty Inputs, Accum set to 0"
	accum=0	
	endif
	duplicate/free statewave statehold
	statehold[][1]+=forceoff
	if(accum==1)
		Concatenate/NP=0 {FoldCollect,FoldedAcc}, FoldedResult
		Concatenate/NP=0 {UnFoldCollect,Unfoldedacc }, UnFoldedResult
		duplicate/o FoldedResult,FoldedAcc
		duplicate/o UnFoldedResult,Unfoldedacc
		DeletePoints 0,1, StateHold
		StateHold[][0]+=AccState[dimsize(AccState,0)-1][0]
		StateHold[][3]+=AccState[dimsize(AccState,0)-1][3]
		StateHold[][4]+=AccState[dimsize(AccState,0)-1][4]
		Concatenate/NP=0 {AccState, StateHold}, StateResult
		duplicate/o StateResult,AccState
		killwaves FoldedResult,UnFoldedResult,StateResult
	else
		duplicate/o FoldCollect FoldedAcc
		duplicate/o UnFoldCollect Unfoldedacc
		duplicate/o statehold AccState
	endif
end




Static Function FindRuptureForcesbyTime(WLCParms,ForceWave,Sepwave,StateWave,FoldingForce,UnfoldingForce)
	wave WLCParms,ForceWave,Sepwave,StateWave,FoldingForce,UnfoldingForce
	variable maxcycle=Statewave[dimsize(StateWave,0)-1][3]
	variable n
	make/free/n=0 MFoldingForce,MUnfoldingForce,FoldingForceFree,UnfoldingForceFree
	FindRuptureForcesbyTimebyIndex(0,WLCParms,ForceWave,Sepwave,StateWave,FoldingForceFree,UnfoldingForceFree)
	for(n=1;n<maxcycle;n+=1)
		FindRuptureForcesbyTimebyIndex(n,WLCParms,ForceWave,Sepwave,StateWave,MFoldingForce,MUnfoldingForce)
		
		Concatenate/o/NP=0 {FoldingForceFree,MFoldingForce}, HoldFolding
		duplicate/free HoldFolding FoldingForceFree
		Concatenate/o/NP=0 {unFoldingForceFree,MunFoldingForce}, HoldunFolding
		duplicate/free HoldunFolding unFoldingForceFree

	endfor
	duplicate/o FoldingForceFree FoldingForce
	duplicate/o UnfoldingForceFree UnfoldingForce
	killwaves HoldunFolding,HoldFolding

end

Static Function/C FindStatesbyTime(Force,WLCParms,ForceWave,Sepwave,StateWave)
	variable Force
	wave WLCParms,ForceWave,Sepwave,StateWave
	//variable T=startmstimer
	variable maxcycle=Statewave[dimsize(StateWave,0)-1][3]
	variable/c SumStates,ThisLoop
	SumStates=cmplx(0,0)
	variable n
	variable/c ThisIndex
	for(n=0;n<maxcycle;n+=1)
	 ThisIndex=FindStatesbyTimebyIndex(Force,n,WLCParms,ForceWave,Sepwave,StateWave)

	SumStates+= ThisIndex
	endfor
	//print stopmstimer(T)/1e6
	return SumStates
end

Static Function ProduceHistogram(Inwave,OutWave,number)
	wave Inwave,OutWave
	variable number
	make/free/n=(dimsize(Inwave,0)) Forces
	Forces=Inwave[p][3]
	make/o/n=(number) Histhold
	Histogram/C/B=1 Forces Histhold
	duplicate/o Histhold OutWave
end



Static Function SmartProduceHistograms(Inwave,OutWave,spacing)
	wave Inwave,OutWave
	variable spacing
	if(dimsize(Inwave,1)==0)
	duplicate/o Inwave Forces
	else
	make/free/n=(dimsize(Inwave,0)) Forces
	Forces=Inwave[p][3]
	endif
	variable Bottom=floor(-1e12*wavemin(Forces))*-1e-12-1e-12-spacing/2
	variable Top=ceil(-1e12*wavemax(Forces))*-1e-12+1e-12+spacing/2
	variable Number=(Top-Bottom)/spacing

	make/free/n=(number+1) Histhold
	setscale/P  x Bottom,spacing,"" Histhold
	Histogram/C/B=2 Forces Histhold
	duplicate/o Histhold OutWave
end


Static Function CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			break
		case -1: // control being killed
			break
	endswitch

	return 02
End

Static Function ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Strswitch(ba.ctrlname)
			string saveDF
			
		case "de_Dudko_button0":
			switch( ba.eventCode )
				case 2: // mouse up
					MakeTheWaves()

					break
				case -1: // control being killed
					break
			endswitch
			break
		case "de_Dudko_button1":
			switch( ba.eventCode )
				case 2: // mouse up
					AccumulateButton()
					ForceStateAccum()
					break
				case -1: // control being killed
					break
			endswitch
			break
		case "de_Dudko_button2":
			switch( ba.eventCode )
				case 2: // mouse up
					FittheContour()
					NewHistogramButton()
					//HistogramButton()
					CreateSlopeWave()
					NumbersCalc()
					MakeRates()
					break
				case -1: // control being killed
					break
			endswitch
			break
		case "de_Dudko_button3":
			switch( ba.eventCode )
				case 2: // mouse up
					Makesomeniceplots()
					break
				case -1: // control being killed
					break
			endswitch
			break
		case "de_Dudko_button4": //Just Histogram
			switch( ba.eventCode )
				case 2: // mouse up
				HistogramButton()
					break
				case -1: // control being killed
					break
			endswitch
			break
			
	endswitch
	return 0
End

Static Function MakeRates()
	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
	wave FoldedForceOut=$(stringfromlist(4,listofnames))
	wave FoldedSepOut=$(stringfromlist(5,listofnames))
	wave unfoldedForceOut=$(stringfromlist(6,listofnames))
	wave unFoldedsepOut=$(stringfromlist(7,listofnames))
	wave WLCParms=$(stringfromlist(8,listofnames))
	wave UnfoldedHist=$(stringfromlist(9,listofnames))
	wave FoldedHist=$(stringfromlist(10,listofnames))
	wave UnfoldedSlope=$(stringfromlist(11,listofnames))
	wave FoldedSlope=$(stringfromlist(12,listofnames))
	wave UnfoldedNum= $stringfromlist(13,listofnames)
	wave FoldedNum=$stringfromlist(14,listofnames)
	duplicate/o UnfoldedHist $(stringfromlist(16,listofnames))
	duplicate/o FoldedHist $(stringfromlist(17,listofnames))
	wave UnfoldedRate=$(stringfromlist(16,listofnames))
	wave FoldedRate=$(stringfromlist(17,listofnames))
	UnfoldedRate=UnfoldedHist/dimdelta(UnfoldedHist,0)*UnfoldedSlope/UnfoldedNum
	FoldedRate=FoldedHist/dimdelta(FoldedHist,0)*FoldedSlope/FoldedNum
end
Static Function MakeSomeNicePlots()
	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
	wave FoldedForceOut=$(stringfromlist(4,listofnames))
	wave FoldedSepOut=$(stringfromlist(5,listofnames))
	wave unfoldedForceOut=$(stringfromlist(6,listofnames))
	wave unFoldedsepOut=$(stringfromlist(7,listofnames))
	wave WLCParms=$(stringfromlist(8,listofnames))
	wave UnfoldedHist=$(stringfromlist(9,listofnames))
	wave FoldedHist=$(stringfromlist(10,listofnames))
	wave UnfoldedSlope=$(stringfromlist(11,listofnames))
	wave FoldedSlope=$(stringfromlist(12,listofnames))
	wave UnfoldedNum= $stringfromlist(13,listofnames)
	wave FoldedNum=$stringfromlist(14,listofnames)
	wave UnfoldedRate=$(stringfromlist(16,listofnames))
	wave FoldedRate=$(stringfromlist(17,listofnames))

	Display UnfoldedRate,FoldedRate
	AppendToGraph/L=L1 FoldedNum,UnfoldedNum
	AppendToGraph/L=L2 FoldedSlope,UnfoldedSlope
	AppendToGraph/L=L3 FoldedHist,UnfoldedHist
	ModifyGraph freePos(L1)=0
	ModifyGraph freePos(L2)=0
	ModifyGraph freePos(L3)=0
	ModifyGraph axisEnab(left)={0,0.22},axisEnab(L1)={0.25,0.47}
	ModifyGraph axisEnab(L2)={0.52,0.74},axisEnab(L3)={0.79,1}
	ModifyGraph log(left)=1
	ModifyGraph mode($nameofwave(UnfoldedRate))=3,marker($nameofwave(UnfoldedRate))=19, rgb($nameofwave(UnfoldedRate))=(58368,6656,7168);DelayUpdate
	ModifyGraph useMrkStrokeRGB($nameofwave(UnfoldedRate))=1;
	ModifyGraph mode($nameofwave(FoldedRate))=3,marker($nameofwave(FoldedRate))=19;DelayUpdate
	ModifyGraph rgb($nameofwave(FoldedRate))=(14848,32256,47104), useMrkStrokeRGB($nameofwave(FoldedRate))=1

	ModifyGraph mode($nameofwave(FoldedNum))=4,marker($nameofwave(FoldedNum))=29;DelayUpdate
	ModifyGraph rgb($nameofwave(FoldedNum))=(14848,32256,47104),useMrkStrokeRGB($nameofwave(FoldedNum))=1;
	ModifyGraph mode($nameofwave(UnfoldedNum))=4,marker($nameofwave(UnfoldedNum))=29;DelayUpdate
	ModifyGraph useMrkStrokeRGB($nameofwave(UnfoldedNum))=1
	ModifyGraph lsize($nameofwave(UnfoldedSlope))=1.5, lsize($nameofwave(foldedSlope))=1.5;DelayUpdate
	ModifyGraph rgb($nameofwave(foldedSlope))=(14848,32256,47104), rgb($nameofwave(UnfoldedSlope))=(58368,6656,7168)
	ModifyGraph mode($nameofwave(FoldedHist))=5,rgb($nameofwave(FoldedHist))=(14848,32256,47104)
	ModifyGraph useBarStrokeRGB($nameofwave(FoldedHist))=1,hbFill($nameofwave(FoldedHist))=2
	ModifyGraph mode($nameofwave(unFoldedHist))=5,rgb($nameofwave(unFoldedHist))=(58368,6656,7168);
	ModifyGraph useBarStrokeRGB($nameofwave(unFoldedHist))=1,hbFill($nameofwave(unFoldedHist))=2
	Label bottom "\\f01Force(pN)"
	ModifyGraph fSize=9,font="Arial"
	ModifyGraph prescaleExp(bottom)=12, muloffset={-1,0},prescaleExp(L2)=12,lblPosMode(L1)=1,lblPosMode(L3)=1,lblPosMode(L2)=1
	Label left "\\f01Rate\r (1/s)"
	Label L1 "\\f01Number"
	Label L2 "\\f01Slope \r(pN/s)"
	Label L3 "\\f01Hist"
	�ModifyGraph margin(bottom)=29,margin(top)=14,margin(right)=14,margin(left)=43

end
Static Function FittheContour()
	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
	//	wave AccUn=$stringfromlist(0,listofnames)
	//	wave AccRe=$stringfromlist(1,listofnames)
	wave FoldedForceOut=$stringfromlist(4,listofnames)
	wave FoldedSepOut=$stringfromlist(5,listofnames)
	wave unfoldedForceOut=$stringfromlist(6,listofnames)
	wave unFoldedsepOut=$stringfromlist(7,listofnames)
	make/o/n=0 $stringfromlist(8,listofnames)
	wave OutputResults=$stringfromlist(8,listofnames)
	WLCFitter(FoldedForceOut,FoldedSepOut,unfoldedForceOut,unFoldedsepOut,OutputResults,1)
	display FoldedForceOut vs FoldedSepOut
	appendtograph unfoldedForceOut vs unFoldedsepOut
	wave FFIt=$("fit_"+nameofwave(FoldedForceOut))
	wave UFIt=$("fit_"+nameofwave(unfoldedForceOut))
	appendtograph FFit
	appendtograph UFIt

end 

Static Function CreateSlopeWave()

	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
	wave FoldedForceOut=$stringfromlist(4,listofnames)
	wave FoldedSepOut=$stringfromlist(5,listofnames)
	wave unfoldedForceOut=$stringfromlist(6,listofnames)
	wave unFoldedsepOut=$stringfromlist(7,listofnames)
	wave WLCParms=$stringfromlist(8,listofnames)
	wave UnfoldedHist=$stringfromlist(9,listofnames)
	wave FoldedHist=$stringfromlist(10,listofnames)
	duplicate/o UnfoldedHist $stringfromlist(11,listofnames)
	
	duplicate/o FoldedHist $stringfromlist(12,listofnames)
	wave UnfoldedSlope=$stringfromlist(11,listofnames)
	wave FoldedSlope=$stringfromlist(12,listofnames)
	duplicate/free UnfoldedHist UnFoldedForces
	UnFoldedForces=pnt2x(UnfoldedHist,p)
	duplicate/free foldedHist FoldedForces
	FoldedForces=pnt2x(foldedHist,p)
	variable UnfoldLC=WLCParms[1]
	variable FoldLC=WLCParms[0]
	variable Offset=WLCParms[2]

	//	variable/C slopes=DE_DUDKO#ReturnSeparationSlopes(SFilt,States,2000)
	//	print slopes
	//	variable pointstoignore=floor(5e-9/real(slopes)/dimdelta(FFilt,0))
	//variable/c Slopes=cmplx(18.2e-9,18.2e-9)
		//variable/c Slopes=cmplx(4.61585e-08,4.61585e-08)

	//variable/c Slopes=cmplx(18.2e-9,18.2e-9)
	controlinfo/W=DudkoAnalysis de_Dudko_setvar2
	variable slopes=V_Value
	UnfoldedSlope=WLCSlopeAtForce(UnfoldLC,Offset,UnFoldedForces,slopes)
	FoldedSlope=WLCSlopeAtForce(FoldLC,Offset,FoldedForces,slopes)
	UnfoldedSlope*=-1
	FoldedSlope*=-1
end

Static Function CalculatePullingSpeed()

	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
	wave FoldedSepOut=$stringfromlist(5,listofnames)
	wave unFoldedsepOut=$stringfromlist(7,listofnames)
	Duplicate/o FoldedSepOut,FoldedSamp
	Duplicate/o UnFoldedSepOut,UnFoldedSamp

	Resample/DOWN=51/N=501 FoldedSamp
	Resample/DOWN=51/N=501 UnFoldedSamp
	make/o/n=0 FoldedDif,UnfoldedDif
	Differentiate FoldedSamp/D=FoldedDif
	Differentiate UnFoldedSamp/D=UnfoldedDif
	Make/N=100/O TestFoldedHist,TestUnFoldedHist
	Histogram/C/b={-5e-8,1e-9,100}  FoldedDif,TestFoldedHist
	Histogram/c/b={-5e-8,1e-9,100} UnfoldedDif,TestUnFoldedHist

end




Static Function WLCSlopeAtForce(LC,Offset,Force,rate)
	variable LC,Offset,Force,rate
	variable z=DE_WLC#ReturnExtentionatForce(Force+Offset,-.4e-9,LC,298)
	return WLCSlope(z,-.4e-9,LC,298)*rate
end

Static Function NumbersCalc()
	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
	wave JustForce=$stringfromlist(2,listofnames)
	wave JustSep=$stringfromlist(3,listofnames)
	wave CompState=$stringfromlist(15,listofnames)
	wave WLCParms=$(stringfromlist(8,listofnames))
	wave UnfoldedHist=$stringfromlist(9,listofnames)
	wave FoldedHist=$stringfromlist(10,listofnames)
	duplicate/o UnfoldedHist $stringfromlist(13,listofnames)
	duplicate/o FoldedHist $stringfromlist(14,listofnames)
	wave UnfoldedNum= $stringfromlist(13,listofnames)
	wave FoldedNum=$stringfromlist(14,listofnames)
	duplicate/free UnfoldedHist UnFoldedForces
	UnFoldedForces=pnt2x(UnfoldedHist,p)
	duplicate/free foldedHist FoldedForces
	FoldedForces=pnt2x(foldedHist,p)
	
	make/free/n=0 FFilt,SFilt
	DE_Filtering#FilterForceSep(JustForce,JustSep,FFilt,SFilt,"svg",51)
	UnfoldedNum= 	real(FindStatesbyTime(UnFoldedForces,WLCParms,FFilt,SFilt,CompState))
	FoldedNum= imag(FindStatesbyTime(FoldedForces,WLCParms,FFilt,SFilt,CompState))
	
	//FFilt*=-1
	//UnFoldedForces*=-1
	//FoldedForces*=-1
	//print mean(FFilt)
	//print UnFoldedForces
	//FindStatesbyTime(Force,WLCParms,ForceWave,Sepwave,StateWave)
	//UnfoldedNum= 	real(CalculateStateExistance(UnFoldedForces,CompState,SFilt,WLCParms))
	//FoldedNum= imag(CalculateStateExistance(FoldedForces,CompState,SFilt,WLCParms))
	
	
//	make/free/n=0 FFilt,SFilt
//	DE_Filtering#FilterForceSep(JustForce,JustSep,FFilt,SFilt,"tvd",200e-9)
//	FFilt*=-1
//	UnFoldedForces*=-1
//	FoldedForces*=-1
//	UnfoldedNum= NumberofTracesinState(FFilt,CompState,UnFoldedForces,-1,1)
//	FoldedNum= NumberofTracesinState(FFilt,CompState,FoldedForces,1,1)

end

Static Function NumberofTracesinState(ForceWaveSM,CombinedWave,Force,State,Smoothed)
	wave ForceWaveSM, CombinedWave
	variable Force,State,Smoothed
	variable n,FoldedMax,UnfoldedMax,q
	String StateList=""
	
	If(Smoothed==1)
		duplicate/free ForceWaveSM FWAll
	else
		duplicate/free ForceWaveSM FWAll
		Smooth/S=2 101, FWALL
		FWALL*=-1
	endif
	
	make/free/n=(dimsize(CombinedWave,0)) Points,RupForce,Type,Trace
	make/T/free/n=0 HoldOnToStates
	Points=CombinedWave[p][0]
	RupForce=-CombinedWave[p][1]
	Type=CombinedWave[p][2]
	Trace=CombinedWave[p][3]
	//for(n=5;n<6;n+=1)
	for(n=0;n<Trace[numpnts(Trace)-1][2];n+=1)
		Extract/INDX/Free Points, LocalSet, Trace==n
		make/free/n=(numpnts(LocalSet)+1) LocalPoints,LocalType,LocalTrace
		LocalPoints[]=Points[LocalSet[0]+p][0]
		LocalType[]=Type[LocalSet[0]+p][2]
		LocalTrace[]=Trace[LocalSet[0]+p][2]
		FindValue/V=-2/T=.01 LocalType
		duplicate/free/r=[,V_value] LocalPoints UpDir
		duplicate/free/r=[V_value+1,] LocalPoints DownDir
		duplicate/free/r=[UpDir[0],UpDir[numpnts(UpDir)-1]] FWALL FW
		FindLevels/Q FW,Force		
		wave W_FindLevels

		if(numpnts(W_FindLevels)==0)
			wavestats/q FW
			if(v_max<Force)
				StateList+="1"
			elseif(Force<v_min)
				StateList+="-1"

			else

			endif
		else
			duplicate/o W_FindLevels TagYU,TagXU
TagYU=FW(TagXU)
			for(q=0;q<numpnts(W_FindLevels);q+=1)
				StateList+=num2str(StateAtPoint(x2pnt(FWALL,W_FindLevels[q]),CombinedWave))+";"
			endfor
		endif
		if(FindListItem(num2str(State), StateList)==-1)
		
		else
			InsertPoints 0, 1,HoldOnToStates
			HoldOnToStates[0]=num2str(LocalTrace[0])+"U"
		endif
		StateList=""
		
		
		duplicate/free/r=[UpDir[numpnts(UpDir)-1],DownDir[numpnts(DownDir)-1]] FWALL FW
		
		FindLevels/Q FW,Force		
		wave W_FindLevels

		if(numpnts(W_FindLevels)==0)
			wavestats/Q FW
			if(v_max<Force)
				StateList+="1"
			elseif(Force<v_min)
				StateList+="-1"

			else
						
			endif
		else
duplicate/o W_FindLevels TagYD,TagXD
TagYD=FW(TagXD)
			for(q=0;q<numpnts(W_FindLevels);q+=1)
				StateList+=num2str(StateAtPoint(x2pnt(FWALL,W_FindLevels[q]),CombinedWave))+";"
			endfor
	
			endif
			if(FindListItem(num2str(State), StateList)==-1)
			
		else
			InsertPoints 0, 1,HoldOnToStates
			HoldOnToStates[0]=num2str(LocalTrace[0])+"D"
		endif
		StateList=""
		
	endfor
	killwaves W_FindLevels
	
	return numpnts(HoldOnToStates)
end
Static Function StateAtPoint(Point,CombinedWave)
	variable Point
	Wave CombinedWave
	
	make/free/n=(dimsize(CombinedWave,0)) Locations,States
	
	Locations=CombinedWave[p][0]
	if(Point==0)
		return -1
	endif
	
	FindLevel/Q Locations,Point
	if(floor(V_levelX)==0)
		return -1
	endif
	
	variable before=floor(V_LevelX)
	if(CombinedWave[before][2]==-2||CombinedWave[before][2]==2)
		before-=1
	endif
		
	if(CombinedWave[before][2]==-1)
		return 1
	else
		return -1
	endif

end
Static Function MakeTheWaves()
	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	SetDataFolder S_Value

	controlinfo/W=DudkoAnalysis de_Dudko_setvar0
	string BaseName=S_Value
	String AccFold=BaseName+"_AccFold"
	String AccUnFold=BaseName+"_AccUnFold"
	String CompState=BaseName+"_CompState"

	String FECForce=BaseName+"_Force"
	String FECSep=BaseName+"_Sep"

	String FECFoldedForce=BaseName+"_FoldedForce"
	String FECFoldedSep=BaseName+"_FoldedSep"
	String FECUnFoldedForce=BaseName+"_UnFoldedForce"
	String FECUnFoldedSep=BaseName+"_UnFoldedSep"
	
	make/o/n=0 $AccFold,$AccUnFold,$FECFoldedForce, $FECFoldedSep, $FECUnFoldedForce, $FECUnFoldedSep,$FECForce,$FECSep,$CompState
	SetDataFolder saveDF

end


Static Function ForceStateAccum()

	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
	wave JustForce=$stringfromlist(2,listofnames)
	wave JustSep=$stringfromlist(3,listofnames)
	wave FoldedForceOut=$stringfromlist(4,listofnames)
	wave FoldedSepOut=$stringfromlist(5,listofnames)
	wave unfoldedForceOut=$stringfromlist(6,listofnames)
	wave unFoldedsepOut=$stringfromlist(7,listofnames)


	controlinfo/W=DudkoAnalysis de_Dudko_popup2
	string ForceFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup3
	wave ForceWave=$(ForceFolder+S_Value)
	wave SepWave=$(ForceFolder+replacestring("Force",S_Value,"Sep"))
	controlinfo/W=DudkoAnalysis de_Dudko_popup4
	wave StateWave=$(ForceFolder+S_Value)
	
//	//variable MinSpacing=3000
//	wave ForceSm=$(ForceFolder+nameofwave(ForceWave)+"_sm")
//	wave SepSm=$(ForceFolder+nameofwave(SepWave)+"_sm")
	make/free/n=0 FFilt,SFilt
	DE_Filtering#FilterForceSep(ForceWave,SepWave,FFilt,SFilt,"TVD",25e-9)
	
	variable/C slopes=DE_Dudko#ReturnSeparationSlopes(SFilt,StateWave,500)
	variable pointstoignore=floor(2e-9/real(slopes)/dimdelta(FFilt,0))
	//AccumulateAllRuptures(StateWave,ForceWave,AccRe,AccUn,Restart)
	make/free/n=0 TempFoldedForceOut,TempFoldedSepOut,TempUnFoldedForceOut,TempUnFoldedSepOut
	ReturnFoldandUnfold(FFilt,SFilt,StateWave,pointstoignore,TempFoldedForceOut,TempFoldedSepOut,TempUnFoldedForceOut,TempUnFoldedSepOut)
	variable forceoff,sepoff
		controlinfo de_dudko_check0

	variable/C Offsets=CorrectionBasedonRequest(ForceWave,V_Value)
	forceoff=real(Offsets)
	sepoff=imag(Offsets)
//	controlinfo de_dudko_check0
//	if(V_value==1)
//	controlinfo de_Dudko_setvar3
//	forceoff=ChangeTheForce(ForceWave,v_value)
//	else
//		forceoff=0
//
//	endif
//	
//		controlinfo de_dudko_check1
//	if(V_value==1)
//		controlinfo de_Dudko_setvar4
//
//	sepoff=de_NEWdUDKO#ChangeTheSep(ForceWave,v_value)
//	else
//		sepoff=0
//
//	endif
	duplicate/free ForceWave ForceWaveTemp
	duplicate/free SepWave SepWaveTemp
	ForceWaveTemp+=forceoff
	SepWaveTemp+=sepoff
	TempFoldedForceOut+=forceoff
	TempFoldedSepOut+=sepoff
	TempUnFoldedForceOut+=forceoff
	TempUnFoldedSepOut+=sepoff
	
	variable first
	if(numpnts(JustForce)==0)
	first=1	
	endif
	
	variable accum=1
	if(accum==1)
		
		Concatenate/NP=0 {JustForce,ForceWaveTemp }, JustForceResult
		duplicate/o JustForceResult,JustForce
		note/k JustForce note(ForceWaveTemp)
		Concatenate/NP=0 {JustSep,SepWaveTemp}, JustSepResult
		duplicate/o JustSepResult,JustSep
		note/k JustSep note(SepWaveTemp)

		Concatenate/NP=0 {FoldedForceOut,TempFoldedForceOut}, FoldedForceResult
		duplicate/o FoldedForceResult,FoldedForceOut
		Concatenate/NP=0 {FoldedSepOut,TempFoldedSepOut }, FoldedSepResult
		duplicate/o FoldedSepResult,FoldedSepOut
		Concatenate/NP=0 {UnFoldedForceOut,TempUnFoldedForceOut}, UnFoldedForceResult
		duplicate/o UnFoldedForceResult,UnFoldedForceOut
		Concatenate/NP=0 {UnFoldedSepOut,TempUnFoldedSepOut }, UnFoldedSepResult

		duplicate/o UnFoldedSepResult,UnFoldedSepOut
		killwaves FoldedForceResult,FoldedSepResult,UnFoldedForceResult,UnFoldedSepResult,JustForceResult,JustSepResult

	else
	duplicate/o TempFoldedForceOut FoldedForceOut
	duplicate/o TempFoldedSepOut FoldedSepOut
	duplicate/o TempUnFoldedForceOut UnFoldedForceOut
	duplicate/o TempUnFoldedSepOut UnFoldedSepOut
	duplicate/o ForceWaveTemp JustForce
	duplicate/o SepWaveTemp JustSep

	endif
	if(First==1)
	SetScale/P x 0,1/(5e4),"", FoldedForceOut,FoldedSepOut,UnFoldedForceOut,UnFoldedSepOut,JustForce,JustSep
	
	endif

end

Static Function HistogramButton()
	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
	wave AccUn=$stringfromlist(0,listofnames)
	wave AccRe=$stringfromlist(1,listofnames)

	make/o/n=0 $(AccFolder+nameofwave(AccUn)+"_Hist"),$(AccFolder+nameofwave(AccRe)+"_Hist")
	wave UnHist=$(AccFolder+nameofwave(AccUn)+"_Hist")
	wave ReHist=$(AccFolder+nameofwave(AccRe)+"_Hist")
	controlinfo/w=DudkoAnalysis de_Dudko_setvar1
	
	SmartProduceHistograms(AccUn,UnHist,v_value*2)
	SmartProduceHistograms(AccRe,ReHist,v_value)

	SetDataFolder saveDF
end

Static Function NewHistogramButton()
	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
		wave AccUn=$stringfromlist(0,listofnames)
	wave AccRe=$stringfromlist(1,listofnames)
	wave ForceWave= $stringfromlist(2,listofnames)
	wave Sepwave= $stringfromlist(3,listofnames)
	Wave WLCParms= $stringfromlist(8,listofnames)
	wave StateWave=$stringfromlist(15,listofnames)

	make/o/n=0 OGFoldingForce,OGUnfoldingForce
	FindRuptureForcesbyTime(WLCParms,ForceWave,Sepwave,StateWave,OGFoldingForce,OGUnfoldingForce)

//
	make/o/n=0 $(AccFolder+nameofwave(AccUn)+"_Hist"),$(AccFolder+nameofwave(AccRe)+"_Hist")
	wave UnHist=$(AccFolder+nameofwave(AccUn)+"_Hist")
	wave ReHist=$(AccFolder+nameofwave(AccRe)+"_Hist")
	controlinfo/w=DudkoAnalysis de_Dudko_setvar1
	
	SmartProduceHistograms(OGUnfoldingForce,UnHist,v_value*2)
	SmartProduceHistograms(OGFoldingForce,ReHist,v_value)

	SetDataFolder saveDF
end

Static Function AccumulateButton()

	string saveDF = GetDataFolder(1)
	controlinfo/W=DudkoAnalysis de_Dudko_popup0
	string AccFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup1
	string listofNames=StringListofAccnames(s_value,AccFolder)
	wave AccUn=$stringfromlist(0,listofnames)
	wave AccRe=$stringfromlist(1,listofnames)
	wave CompState=$stringfromlist(15,listofnames)
	controlinfo/W=DudkoAnalysis de_Dudko_popup2
	string ForceFolder=S_Value
	controlinfo/W=DudkoAnalysis de_Dudko_popup3
	wave ForceWave=$(ForceFolder+S_Value)
	controlinfo/W=DudkoAnalysis de_Dudko_popup4
	wave StateWave=$(ForceFolder+S_Value)
	AccumulateAllRuptures(StateWave,ForceWave,CompState,AccRe,AccUn,1)
end

Static Function/S StringListofAccnames(InputName,FolderStr)
	String InputName,FolderStr
	string listofNames=FolderStr+InputName
	listofNames+=";"+FolderStr+ReplaceString("Unfold",InputName,"Fold")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"Force")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"Sep")

	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"FoldedForce")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"FoldedSep")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"UnFoldedForce")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"UnFoldedSep")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"WLCParms")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"AccUnFold_Hist")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"AccFold_HIst")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"AccUnFold_Slope")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"AccFold_Slope")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"AccUnFold_Num")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"AccFold_Num")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"CompState")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"AccUnFold_Rate")
	listofNames+=";"+FolderStr+ReplaceString("AccUnFold",InputName,"AccFold_Rate")
	return listofNames
end

Static Function SVP(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

End

Static Function WLCFitter(FoldedForceWave,FoldedSepWave,UnFoldedForceWave,UnFoldedSepWave,OutputResults,fitfoldedfirst)
	Wave FoldedForceWave,FoldedSepWave,UnFoldedForceWave,UnFoldedSepWave,OutputResults
	variable fitfoldedfirst
	make/free/n=0 W_coef
	variable fitstart=FoldedSepWave[0]-10e-9,FoldedContour,ForceOffset,UnfoldedContour

	W_coef[0] = {-.4e-9,100e-9,298,0,fitstart}
	Make/free/T/N=2 T_Constraints
//	//T_Constraints[0] = {"K4<"+num2str(fitstart+3e-9),"K4>"+num2str(fitstart-30e-9),"K3<"+num2str(1e-12),"K3>"+num2str(-1e-12)}
	T_Constraints[0] = {"K4<"+num2str(fitstart+10e-9),"K4>"+num2str(fitstart-30e-9)}
	if(FitFOldedFirst==1)
		FuncFit/Q/H="10100"/NTHR=0 WLC_FIT W_coef  FoldedForceWave /X=FoldedSepWave/C=T_Constraints/D

		fitstart=w_coef[4]
		FoldedContour=w_coef[1]		
		ForceOffset=w_coef[3]		
		W_coef[0] = {-.4e-9,w_coef[1]+40e-9,298,w_coef[3],w_coef[4]}
		FuncFit/Q/H="10111"/NTHR=0 WLC_FIT W_coef  UnFoldedForceWave /X=UnFoldedSepWave/D
		UnfoldedContour=w_coef[1]
		ForceOffset=w_coef[3]
	else
		FuncFit/Q/H="10100"/NTHR=0 WLC_FIT W_coef  UnFoldedForceWave /X=UnFoldedSepWave/C=T_Constraints/D
		fitstart=w_coef[4]
		UnfoldedContour=w_coef[1]
		ForceOffset=w_coef[3]
		W_coef[0] = {-.4e-9,w_coef[1]-10e-9,298,w_coef[3],w_coef[4]}
		FuncFit/Q/H="10111"/NTHR=0 WLC_FIT W_coef  FoldedForceWave /X=FoldedSepWave/D
		FoldedContour=w_coef[1]		
		ForceOffset=w_coef[3]	
	endif

	make/free/n=4 Something
	Something={FoldedContour,UnfoldedContour,ForceOffset,fitstart}
	print Something
	duplicate/o Something OutputResults
end

Static Function ChangeTheForce(AlignedWave,DesiredNewForceOffset)
	wave AlignedWave
	variable DesiredNewForceOffset
	return DesiredNewForceOffset+str2num(stringbykey("UsedAlignmentFShift",note(AlignedWave),":","\r"))

end

Static Function ChangeTheSep(AlignedWave,DesiredNewSepOffset)
	wave AlignedWave
	variable DesiredNewSepOffset
	
	return DesiredNewSepOffset-str2num(stringbykey("UsedAlignmentSShift",note(AlignedWave),":","\r"))

end

Window DudkoAnalysis() : Panel

	PauseUpdate; Silent 1		// building window...
	NewPanel/N=DudkoAnalysis /W=(0,0,600,300)
	NewDataFolder/o root:DE_Dudko
	NewDataFolder/o root:DE_Dudko:MenuStuff
	
	SetVariable de_Dudko_setvar0,pos={15,2},size={150,21},value=_STR:"Image",title="Name"
	PopupMenu de_Dudko_popup0,pos={170,2},size={125,21},Title="Acc Fold"
	PopupMenu de_Dudko_popup0,mode=1,popvalue="X",value= #"DE_PanelProgs#ListFolders()"
	Button de_Dudko_button0,pos={320,2},size={100,21},proc=DE_NewDudko#ButtonProc,title="MakeWaves!"


	PopupMenu de_Dudko_popup1,pos={15,50},size={129,21},Title="AccumulateFile",proc=DE_NewDudko#PopMenuProc
	PopupMenu de_Dudko_popup1,mode=1,popvalue="X",value= #"DE_NewDudko#ListWaves(\"de_Dudko_popup0\",\"*Acc*Unf*\")"

	PopupMenu de_Dudko_popup2,pos={75,90},size={129,21},Title="ForceFolder"
	PopupMenu de_Dudko_popup2,mode=1,popvalue="X",value= #"DE_PanelProgs#ListFolders()"
	PopupMenu de_Dudko_popup3,pos={15,120},size={129,21},Title="Force",proc=DE_NewDudko#PopMenuProc
	PopupMenu de_Dudko_popup3,mode=1,popvalue="X",value= #"DE_NewDudko#ListWaves(\"de_Dudko_popup2\",\"*Force*\")"
	PopupMenu de_Dudko_popup4,pos={200,120},size={129,21},Title="State"
	PopupMenu de_Dudko_popup4,mode=1,popvalue="X",value= #"DE_NewDudko#ListWaves(\"de_Dudko_popup2\",\"*State*\")"
//	
//	CheckBox de_Dudko_check0 title="Restart?",pos={275,45},size={150,25},proc=DE_NewDudko#CheckProc
	Button de_Dudko_button1,pos={75,150},size={50,21},proc=DE_NewDudko#ButtonProc,title="GO!"
	Button de_Dudko_button2,pos={75,175},size={150,21},proc=DE_NewDudko#ButtonProc,title="Find Contour"
	Button de_Dudko_button3,pos={75,210},size={150,21},proc=DE_NewDudko#ButtonProc,title="Make plots"
	Button de_Dudko_button4,pos={75,250},size={150,21},proc=DE_NewDudko#ButtonProc,title="JustHistogram"

	SetVariable de_Dudko_setvar1,pos={250,175},size={150,16},value= _num:10,title="Bins"
	SetVariable de_Dudko_setvar2,pos={350,175},size={150,16},value= _num:20e-9,title="Velocity"
	checkbox de_Dudko_Check0,pos={350,50},size={150,16},title="ShiftS?"
	//checkbox de_Dudko_Check1,pos={450,50},size={150,16},title="ShiftS?"
	SetVariable de_Dudko_setvar3,pos={275,80},size={150,16},value= _num:0,title="FOff"
	SetVariable de_Dudko_setvar4,pos={450,80},size={150,16},value= _num:0,title="SOff"
EndMacro

Static Function/S ListWaves(ControlStr,SearchStr)
	string ControlStr,SearchStr
	String saveDF
//	controlinfo/w=CTFCProcPanel de_CTFCProc_setvar2
//	SearchStr=S_Value
	saveDF = GetDataFolder(1)
	controlinfo $ControlStr
	SetDataFolder s_value
	String list = WaveList(SearchStr, ";", "")
	SetDataFolder saveDF
	return list

end

Static Function/C ReturnFoldandUnfold(ForceWaveSM,SepWaveSm,CombinedWave,MinSpacing,FoldedForceOut,FoldedSepOut,UnFoldedForceOut,UnFoldedSepOut)
	wave ForceWaveSM, SepWaveSm,CombinedWave,FoldedForceOut,FoldedSepOut,UnFoldedForceOut,UnFoldedSepOut
	variable MinSpacing
	variable n,FoldedMax,UnfoldedMax,q
	
	make/free/n=(dimsize(CombinedWave,0)) Points,RupForce,Type,Trace
	//make/free/n=0 HoldOnToCF,HoldOnToCU,HoldOnToF,HoldOnToOff,Unfolded,UnfoldedSep,Folded,FoldedSep,HoldN
	Points=CombinedWave[p][0]
	RupForce=CombinedWave[p][1]
	Type=CombinedWave[p][2]
	Trace=CombinedWave[p][3]
	
	variable fitstart=SepWaveSm[0]-10e-9,firstfit,FOFF
	//fitstart=6.12917e-07
	variable lastpoint=0,firstone,firstmone,NewZero
	variable LastNType
	//for(n=1;n<50;n+=1)

	for(n=1;n<numpnts(points);n+=1)
		
	
	
		if(Type[n]==-1)
			if((Points[n]-lastpoint)<=0)
				lastpoint=Points[n]+minspacing
			else
				if(firstmone==0)

					duplicate/free/r=[0,Points[n]] ForceWaveSM, Folded
					duplicate/free/r=[0,Points[n]] SepWaveSm, FoldedSep
					LastNType=Type[n]

					firstmone=1
				else		
	
					duplicate/free/r=[lastpoint,Points[n]] ForceWaveSM, NewSection
					//NewSection-=ForceShift
					duplicate/free/r=[lastpoint,Points[n]] SepWaveSm, NewSectionSep
					LastNType=Type[n]

					DE_Dudko#AppendToWaveWOverlap(Folded,NewSection)
					DE_Dudko#AppendToWaveWOverlap(FoldedSep,NewSectionSep)

				endif
			endif
			
			lastpoint=Points[n]+minspacing
		endif	
	
		if(Type[n]==1)
			if((Points[n]-lastpoint)<=0)
				lastpoint=Points[n]+minspacing


			else
				if(firstone==0)
					duplicate/free/r=[lastpoint,Points[n]] ForceWaveSM, UnFolded
					//UnFolded[0,lastpoint-NewZero]=NaN
					duplicate/free/r=[lastpoint,Points[n]] SepWaveSm, UnFoldedSep
					//UnFoldedSep[0,lastpoint-NewZero]=NaN
					firstone=1
					LastNType=Type[n]

				else		

					duplicate/free/r=[lastpoint,Points[n]] ForceWaveSM, NewSection

					duplicate/free/r=[lastpoint,Points[n]] SepWaveSm, NewSectionSep
					LastNType=Type[n]

					DE_Dudko#AppendToWaveWOverlap(UnFolded,NewSection)
					DE_Dudko#AppendToWaveWOverlap(UnFoldedSep,NewSectionSep)

				endif

			endif
			lastpoint=Points[n]+minspacing
		endif

	endfor
	if((Points[n-1]-lastpoint)<=0)

	else
		duplicate/free/r=[lastpoint,Points[n-1]] ForceWaveSM, NewSection
		duplicate/free/r=[lastpoint,Points[n-1]] SepWaveSm, NewSectionSep
		DE_Dudko#AppendToWaveWOverlap(Folded,NewSection)
		DE_Dudko#AppendToWaveWOverlap(FoldedSep,NewSectionSep)
	endif

	duplicate/o FoldedSep FoldedSepOut
	duplicate/o Folded	FoldedForceOut
	duplicate/o UnfoldedSep UnFoldedSepOut
	duplicate/o Unfolded UnFoldedForceOut
	
end



Menu "Ramp"
	//SubMenu "Processing"
	"Open Dudko", DudkoAnalysis()


	//end
	
end

//Function SplitWaveForMe(ForceWave,SepWave,StateWave,ForceRetOut,SepRetOut,ForceExtOut,SepExtOut)
//	wave ForceWave,SepWave,Statewave,ForceRetOut,SepRetOut,ForceExtOut,SepExtOut
//	variable maxcycle=Statewave[dimsize(StateWave,0)-1][3]
//
//	make/free/n=(dimsize(Statewave,0)) Points,RupForce,Type,Trace
//	Points=Statewave[p][0]
//	RupForce=-Statewave[p][1]
//	Type=Statewave[p][2]
//	Trace=Statewave[p][3]
//	variable n=0
//	Extract/INDX/Free Points, LocalIndex, Trace==0
//	make/free/n=(numpnts(LocalIndex)+1) LocalPoints,LocalType,LocalTrace
//	LocalPoints[]=Points[LocalIndex[0]+p][0]
//	LocalType[]=Type[LocalIndex[0]+p][2]
//	LocalTrace[]=Trace[LocalIndex[0]+p][2]
//	FindValue/V=-2/T=.1 LocalType
//	variable turnaround=v_value
//	duplicate/free/R=[LocalPoints[0],LocalPoints[turnaround]] SepWave, SepRetH
//	duplicate/free/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-2]] SepWave ,SepExtH
//	duplicate/free/R=[LocalPoints[0],LocalPoints[turnaround]] ForceWave, ForceRetH
//	duplicate/free/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-2]] ForceWave, ForceExtH
//	variable lengthret=numpnts(SepRetH)
//	variable lengthext=numpnts(SepExtH)
//
//	for(n=1;n<maxcycle;n+=1)
//
//		Extract/INDX/Free Points, LocalIndex, Trace==n
//		make/free/n=(numpnts(LocalIndex)+1) LocalPoints,LocalType,LocalTrace
//		LocalPoints[]=Points[LocalIndex[0]+p][0]
//		LocalType[]=Type[LocalIndex[0]+p][2]
//		LocalTrace[]=Trace[LocalIndex[0]+p][2]
//		FindValue/V=-2/T=.1 LocalType
//		turnaround=v_value
//		duplicate/free/R=[LocalPoints[0],LocalPoints[turnaround]] SepWave, SEP1
//		duplicate/free/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-2]] SepWave ,SEP2
//		duplicate/free/R=[LocalPoints[0],LocalPoints[turnaround]] ForceWave, Force1
//		duplicate/free/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-2]] ForceWave, Force2
//		deletepoints lengthret,1e6, SEP1,Force1
//				deletepoints lengthext,1e6, SEP2,Force2
//
//		Concatenate/o {SepRetH,Sep1}, SepFree
//		duplicate/o SepFree SepRetH
//		Concatenate/o/NP=1 {SepExtH,Sep2}, SepFree
//		duplicate/o SepFree SepExtH
//		Concatenate/o/NP=1 {ForceRetH,Force1}, ForceFree
//		duplicate/o ForceFree ForceRetH
//		Concatenate/o/NP=1 {ForceExtH,Force2}, ForceFree
//		duplicate/o ForceFree ForceExtH
//	endfor
//	killwaves ForceFree,SepFree
//	duplicate/o  SepRetH SepRetOut
//	duplicate/o  SepExtH SepExtOut
//
//	duplicate/o  ForceRetH ForceRetOut
//	duplicate/o  ForceExtH ForceExtOut
//
//end
//
Function PullSingle(Forcewave,SepWave,StateWave,n,Direc,ForceOut,SepOut)
	wave Forcewave,SepWave,StateWave,ForceOut,SepOut
	variable n,,Direc //0=Ret, 1=Ext
	make/free/n=(dimsize(Statewave,0)) Points,RupForce,Type,Trace
	Points=Statewave[p][0]
	RupForce=-Statewave[p][1]
	Type=Statewave[p][2]
	Trace=Statewave[p][3]
	Extract/INDX/Free Points, LocalIndex, Trace==n
	make/free/n=(numpnts(LocalIndex)+1) LocalPoints,LocalType,LocalTrace
	LocalPoints[]=Points[LocalIndex[0]+p][0]
	LocalType[]=Type[LocalIndex[0]+p][2]
	LocalTrace[]=Trace[LocalIndex[0]+p][2]
	FindValue/V=-2/T=.1 LocalType
	variable turnaround=v_value
	duplicate/free/R=[LocalPoints[0],LocalPoints[turnaround]] SepWave, SepRet
	duplicate/free/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-2]] SepWave ,SepExt
	duplicate/free/R=[LocalPoints[0],LocalPoints[turnaround]] ForceWave, ForceRet
	duplicate/free/R=[LocalPoints[turnaround],LocalPoints[numpnts(localpoints)-2]] ForceWave, ForceExt

	if(Direc==0)
		wave UseForce=ForceRet
		wave UseSep=SepRet
	elseif(Direc==1)
			wave UseForce=ForceExt
			wave UseSep=SepExt
	endif

	duplicate/o UseForce ForceOut
	duplicate/o UseSep SepOut

end

Static Function GenerateSingleRamp(Forcewave,SepWave,StateWave,n,Direc,Folded,Forceout,SepOut)		
	
	wave Forcewave,SepWave,StateWave,ForceOut,SepOut
	variable n,Direc,Folded
	variable startm,endm,m
	make/free/n=0 ForceOutFree,SepOutFree
		
	PullSingle(ForceWave,SepWave,StateWave,n,Direc,ForceOutFree,SepOutFree)
	variable gap=10
	make/free/n=(dimsize(Statewave,0)) Points,RupForce,Type,Trace
	Points=Statewave[p][0]
	RupForce=-Statewave[p][1]
	Type=Statewave[p][2]
	Trace=Statewave[p][3]
	//	variable n
	//for(n=0;n<maxcycle;n+=1)
	Extract/INDX/Free Points, LocalIndex, Trace==n
	make/free/n=(numpnts(LocalIndex)+1) LocalPoints,LocalType,LocalTrace
	LocalPoints[]=Points[LocalIndex[0]+p][0]
	LocalType[]=Type[LocalIndex[0]+p][2]
	LocalTrace[]=Trace[LocalIndex[0]+p][2]
	FindValue/V=-2/T=.1 LocalType
	variable turnaround=v_value
	variable currfolded
	if(Direc==0)
		startm=1
		endm=turnaround+1
		currfolded=1
	elseif(Direc==1)
		startm=turnaround+1
		endm=numpnts(LocalPoints)-1
		currfolded=1
	endif
	variable verystartpnt=LocalPoints[startm-1]
	variable endpnt
	variable startpnt=0
	for(m=startm;m<endm;m+=1)
		if(LocalType[m]==1)
			endpnt=LocalPoints[m]-verystartpnt
			If(Folded==1)
				ForceOutFree[startpnt,endpnt]=NaN
				SepOutFree[startpnt,endpnt]=NaN
			else
			endif
			startpnt=LocalPoints[m]+gap-verystartpnt
		elseif(LocalType[m]==-1)
			endpnt=LocalPoints[m]-verystartpnt
			If(Folded==1)
			else
				ForceOutFree[startpnt,endpnt]=NaN
				SepOutFree[startpnt,endpnt]=NaN
			endif
			startpnt=LocalPoints[m]+gap-verystartpnt
		elseif(LocalType[m]==-2)
			endpnt=LocalPoints[m]-verystartpnt
			If(Folded==1)
				ForceOutFree[startpnt,endpnt]=NaN
				SepOutFree[startpnt,endpnt]=Nan
			else
			endif
		elseif(LocalType[m]==0)
			endpnt=LocalPoints[m]-verystartpnt
			If(Folded==1)
			else
				ForceOutFree[startpnt,endpnt]=NaN
				SepOutFree[startpnt,endpnt]=Nan
			endif
		endif
	
	endfor
	duplicate/o ForceOutFree ForceOut
	Duplicate/o SepOutFree SepOut
end

Static Function GenerateSepLine(ForceWave,SepWave,StateWave,n,Direc,Folded,OutApprox)
	wave ForceWave,SepWave,StateWave,OutApprox
	variable n,Direc,Folded
	make/free/n=0 SepFree,ForceFree

	GenerateSingleRamp(ForceWave,SepWave,StateWave,n,Direc,Folded,ForceFree,SepFree)

	CurveFit/Q line SepFree
	duplicate/free SepFree,LineFree
	wave W_coef,W_sigma
	LineFree=W_coef[0]+W_coef[1]*x
	duplicate/o LineFree OutApprox
	Killwaves W_coef,W_sigma

end


Static Function PopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
		
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Static Function SimpleLoadingRate()




end