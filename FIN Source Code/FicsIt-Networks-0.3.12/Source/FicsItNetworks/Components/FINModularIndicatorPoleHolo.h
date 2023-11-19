﻿#pragma once
#include "FINModularIndicatorPole.h"
#include "Buildables/FGBuildableFactoryBuilding.h"
#include "Hologram/FGBuildableHologram.h"

#include "FINModularIndicatorPoleHolo.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogFicsItNetworks_DebugRoze, Log, Log);

UCLASS()
class UBuildMode_Auto : public UFGHologramBuildModeDescriptor {
	GENERATED_BODY()
public:
	UBuildMode_Auto();
};

UCLASS()
class UBuildMode_OnVertical : public UFGHologramBuildModeDescriptor {
	GENERATED_BODY()
public:
	UBuildMode_OnVertical();
};

UCLASS()
class UBuildMode_OnHorizontal : public UFGHologramBuildModeDescriptor {
	GENERATED_BODY()
public:
	UBuildMode_OnHorizontal();
};

class AFINModularIndicatorPoleHolo;
UCLASS()
class AFINModularIndicatorPoleHolo : public AFGBuildableHologram {
	GENERATED_BODY()
	
public:
	UPROPERTY( EditDefaultsOnly, Category = "Hologram|BuildMode" )
	TSubclassOf< class UFGHologramBuildModeDescriptor > mBuildModeAuto;
	
	UPROPERTY( EditDefaultsOnly, Category = "Hologram|BuildMode" )
	TSubclassOf< class UFGHologramBuildModeDescriptor > mBuildModeOnVerticalSurface;

	UPROPERTY( EditDefaultsOnly, Category = "Hologram|BuildMode" )
	TSubclassOf< class UFGHologramBuildModeDescriptor > mBuildModeOnHorizontalSurface;
	
	virtual void GetSupportedBuildModes_Implementation( TArray< TSubclassOf<UFGHologramBuildModeDescriptor> >& out_buildmodes ) const override;
	
	UPROPERTY()
	FVector SnappedLoc;

	UPROPERTY()
	bool bSnapped = false;

	UPROPERTY(Replicated)
	bool bFinished = false;

	
	UPROPERTY(Replicated)
	int Extension = 1;
	
	UPROPERTY(Replicated)
	bool Vertical = false;
	
	UPROPERTY(Replicated)
	bool UpsideDown = false;
	
	
	UPROPERTY()
	TArray<UStaticMeshComponent*> Parts;
	FVector Normal;
	bool LastVertical;
	int LastExtension = 0;
	
	FRotator FloorOrientationModifier = FRotator(90,0,0);

	AFINModularIndicatorPoleHolo();

	// Begin AActor
	virtual void Tick(float DeltaSeconds) override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
	virtual void OnConstruction(const FTransform& Transform) override;
	// End AActor

	// Begin AFGBuildableHologram
	virtual bool DoMultiStepPlacement(bool isInputFromARelease) override;
	virtual int32 GetBaseCostMultiplier() const override;
	virtual bool IsValidHitResult(const FHitResult& hitResult) const override;
	virtual void SetHologramLocationAndRotation(const FHitResult& hitResult) override;
	virtual void ConfigureActor(AFGBuildable* inBuildable) const override;
	virtual void CheckValidFloor() override;
	virtual bool TrySnapToActor(const FHitResult& hitResult) override;
	// End AFGBuildableHologram
	
	int GetHeight(FVector worldLoc) const;

	static int GetHitSideSingleAxis(const FVector A, const FVector B);
	static EFoundationSide GetHitSide(FVector AxisX, FVector AxisY, FVector AxisZ, FVector HitNormal);
};