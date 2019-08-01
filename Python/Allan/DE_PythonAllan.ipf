#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma ModuleName=DE_PythonAllan
#include "C:Users:dedwards:src_prh:IgorUtil:IgorCode:Util:OperatingSystemUtil"


function ExecuteAllan(waveOut,method)
	wave Waveout
	string method
	String Destination = "D:\Data\AllanHoldData\Test1.ibw"
	String NewHome = "D:\Data\AllanHoldData\Shit.txt"
	DUPLICATE/O WAVEOUT wAVEY
	wavestats/q wavey
	Wavey-=v_avg  //Set the first point to 0
		
	if(numpnts(Wavey)>.6e8)
		Variable Choice=3
		Prompt Choice,"Choice",popup,"Quit;Decimate;Cut"
		DoPrompt "Too many Points:",Choice
		
		switch(Choice)
			case 1:
				return 0
			break
			
			case 2:
				variable factor=ceil(numpnts(Wavey)/.3e8)
				print "Decimating By: "+num2str(factor)
				Resample/DOWN=(factor)/N=1/WINF=None Wavey
				Make/O/D/N=0 coefs; DelayUpdate
				FilterFIR/DIM=0/LO={0.49,0.5,101}/COEF coefs, Wavey
			break
				deletepoints .5e6,1e8, Wavey
			case 3:
			
		break
		
		endswitch
		
		if (V_Flag)
			return 0									// user canceled
		endif

	endif

	Save/O/C wAVEY as Destination
	killwaves wavey,coefs
	String BasePythonCommand = "python D:\Devin\Python\Allan\Allan.py "
	String MethodCommand="-method "+ method +" "
	String InputCom="-inputfile "+ Destination+" "
	String OutputCom="-outputfile "+ NewHome+" "

	String PythonCommand=BasePythonCommand+MethodCommand+InputCom+OutputCom
	ModOperatingSystemUtil#execute_python(PythonCommand)
	LoadWave/O/A=No/A/G/D NewHome
	wave No0,No1,No2,No3
	note no1, note(waveout)
	note no2, note(waveout)
	note no3, note(waveout)

	string Names=nameofwave(Waveout)
	strswitch(method)
		case "modified":
			duplicate/o No0 $(Names+"_MAdev_tau")
			duplicate/o No1 $(Names+"_MAdev_")
			duplicate/o No2 $(Names+"_MAdev_err")
			break
		case "overlap":
			duplicate/o No0 $(Names+"_OAdev_tau")
			duplicate/o No1 $(Names+"_OAdev_")
			duplicate/o No2 $(Names+"_OAdev_err")
			break
		default:
			duplicate/o No0 $(Names+"_Adev_tau")
			duplicate/o No1 $(Names+"_Adev_")
			duplicate/o No2 $(Names+"_Adev_err")
			break
	endswitch
		
	killwaves No0,No2,No1,No3
end