#pragma once

#include "CoreMinimal.h"
#include "Buildables/FGBuildable.h"
#include "FicsItNetworks/ModuleSystem/FINModuleSystemModule.h"
#include "FicsItNetworks/ModuleSystem/FINModuleSystemPanel.h"
#include "FicsItNetworks/Network/Signals/FINSignalSender.h"

#include "FINComputerModule.generated.h"

UCLASS()
class FICSITNETWORKS_API AFINComputerModule : public AFGBuildable, public IFINModuleSystemModule, public IFINSignalSender {
	GENERATED_BODY()

public:
	UPROPERTY(EditDefaultsOnly, Category="ComputerModule")
	FVector2D ModuleSize;

	UPROPERTY(EditDefaultsOnly, Category="ComputerModule")
	FName ModuleName;

	UPROPERTY(BlueprintReadOnly, SaveGame, Category="ComputerModule")
	FVector ModulePos;

	UPROPERTY(BlueprintReadOnly, SaveGame, Category="ComputerModule")
	UFINModuleSystemPanel* ModulePanel = nullptr;

	// Begin AActor
	virtual void EndPlay(EEndPlayReason::Type reason) override;
	// End AActor
	
	// Begin IFGSaveInterface
	virtual bool ShouldSave_Implementation() const override;
	// End IFGSaveInterface

	// Begin IFINModuleSystemModule
	virtual void setPanel_Implementation(UFINModuleSystemPanel* Panel, int X, int Y, int Rot) override;
	virtual void getModuleSize_Implementation(int& Width, int& Height) const override;
	virtual FName getName_Implementation() const override;
	// End IFINModuleSystemModule

	// Begin IFINSignalSender
	virtual UObject* GetSignalSenderOverride_Implementation() override;
	// End IFINSignalSender
};