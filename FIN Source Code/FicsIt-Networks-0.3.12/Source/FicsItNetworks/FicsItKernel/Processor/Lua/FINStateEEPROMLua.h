﻿#pragma once
#include "FicsItNetworks/FicsItKernel/Processor/FINStateEEPROM.h"
#include "FINStateEEPROMLua.generated.h"

UCLASS()
class AFINStateEEPROMLua : public AFINStateEEPROM {
	GENERATED_BODY()
	
protected:
	UPROPERTY(BlueprintReadWrite, SaveGame, Replicated)
	FString Code;

public:
	UFUNCTION(BlueprintCallable, Category="Computer")
	FString GetCode() const;

	UFUNCTION(BlueprintCallable, Category="Computer")
	void SetCode(const FString& NewCode);

	virtual bool CopyDataTo(AFINStateEEPROM* InFrom) override;
};
