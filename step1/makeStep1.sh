#!/bin/bash

hostname
date

infilename=${1}
outfilename=${2}
inputDir=${3}
outputDir=${4}
idlist=${5}
ID=${6}
Year=${7}
scratch=${PWD}

source /cvmfs/cms.cern.ch/cmsset_default.sh
export SCRAM_ARCH=slc6_amd64_gcc700
scramv1 project CMSSW CMSSW_10_2_10
cd CMSSW_10_2_10
eval `scramv1 runtime -sh`
cd -

echo "setting macroDir to PWD"
macroDir=${PWD}
export PATH=$PATH:$macroDir
root -l -b -q compileStep1.C

XRDpath=root://cmseos.fnal.gov/$inputDir
if [[ $inputDir == /isilon/hadoop/* ]] ;
then
XRDpath=root://brux11.hep.brown.edu:1094/$inputDir
fi

echo "Running step1 over list: ${idlist}"
for iFile in $idlist; do
    inFile=${iFile}
    if [[ $iFile == ext* ]] ;
    then
	inFile=${iFile:4}
    elif [[ $iFile == [ABCDEFWXYZ]* ]] ;
    then
	inFile=${iFile:1}
    fi

    echo "creating ${outfilename}_${iFile}.root by reading ${infilename}_${inFile}"
    root -l -b -q makeStep1.C\(\"$macroDir\",\"$XRDpath/${infilename}_${inFile}.root\",\"${outfilename}_${iFile}.root\",${Year}\)
done

echo "ROOT Files:"
ls -l *.root

# copy output to eos

NOM="nominal"
echo "xrdcp output for condor"
for SHIFT in nominal JECup JECdown JERup JERdown
  do
  haddFile=${outfilename}_${ID}${SHIFT}_hadd.root
  hadd ${haddFile} *${SHIFT}.root
  echo "xrdcp -f ${haddFile} root://cmseos.fnal.gov/${outputDir//$NOM/$SHIFT}/${haddFile//${SHIFT}_hadd/}"
  xrdcp -f ${haddFile} root://cmseos.fnal.gov/${outputDir//$NOM/$SHIFT}/${haddFile//${SHIFT}_hadd/} 2>&1
  XRDEXIT=$?
  if [[ $XRDEXIT -ne 0 ]]; then
    rm *.root
    echo "exit code $XRDEXIT, failure in xrdcp"
    exit $XRDEXIT
  fi
  rm *${SHIFT}.root
  rm ${haddFile}
  if [[ $haddFile == Single* || $haddFile == EGamma*  || $haddFile == JetHT* ]]; then break; fi;
done

echo "done"