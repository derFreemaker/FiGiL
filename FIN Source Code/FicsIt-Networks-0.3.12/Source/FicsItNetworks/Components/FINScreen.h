﻿#pragma once

#include "Components/WidgetComponent.h"
#include "FicsItNetworks/Computer/FINComputerScreen.h"
#include "FicsItNetworks/Graphics/FINScreenInterface.h"
#include "FicsItNetworks/Network/FINAdvancedNetworkConnectionComponent.h"
#include "FINScreen.generated.h"

UCLASS()
class AFINScreen : public AFGBuildable, public IFINScreenInterface {
	GENERATED_BODY()
	
private:
	UPROPERTY(SaveGame, Replicated)
	FFINNetworkTrace GPU;

	UPROPERTY(Replicated)
	UObject* GPUPtr = nullptr;
	
public:
	TSharedPtr<SWidget> Widget;
	
	UPROPERTY(VisibleAnywhere, BlueprintReadWrite)
	UFINAdvancedNetworkConnectionComponent* Connector = nullptr;

	UPROPERTY(VisibleAnywhere, BlueprintReadWrite)
	UWidgetComponent* WidgetComponent = nullptr;

	UPROPERTY(EditDefaultsOnly)
	UStaticMesh* ScreenMiddle = nullptr;

	UPROPERTY(EditDefaultsOnly)
    UStaticMesh* ScreenEdge = nullptr;

	UPROPERTY(EditDefaultsOnly)
	UStaticMesh* ScreenCorner = nullptr;

	UPROPERTY(SaveGame, Replicated)
	int ScreenWidth = 1;

	UPROPERTY(SaveGame, Replicated)
	int ScreenHeight = 1;

	UPROPERTY()
	TArray<UStaticMeshComponent*> Parts;

	bool bGPUChanged = false;
	
	/**
	* This event gets triggered when a new widget got set by the GPU
	*/
	UPROPERTY(VisibleAnywhere, BlueprintReadWrite, BlueprintAssignable)
	FScreenWidgetUpdate OnWidgetUpdate;

	/**
	* This event gets triggered when a new GPU got bound
	*/
	UPROPERTY(VisibleAnywhere, BlueprintReadWrite, BlueprintAssignable)
	FScreenGPUUpdate OnGPUUpdate;
	
	AFINScreen();

	// Begin AActor
	virtual void BeginPlay() override;
	virtual void OnConstruction(const FTransform& transform) override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void EndPlay(const EEndPlayReason::Type endPlayReason) override;
	// End AActor

	// Begin AFGBuildable
	virtual int32 GetDismantleRefundReturnsMultiplier() const override;
	// End AFGBuildable

	// Begin IFGSaveInterface
	virtual bool ShouldSave_Implementation() const override;
	// End IFGSaveInterface

	// Begin IFINScreenInterface
	void BindGPU(const FFINNetworkTrace& gpu) override;
	FFINNetworkTrace GetGPU() const override;
	void SetWidget(TSharedPtr<SWidget> widget) override;
	TSharedPtr<SWidget> GetWidget() const override;
	virtual void RequestNewWidget() override;
	// End IFINScreenInterface

	UFUNCTION(NetMulticast, Reliable)
	void OnGPUValidChanged(bool bValid, UObject* newGPU);

	UFUNCTION()
    void netClass_Meta(FString& InternalName, FText& DisplayName) {
		InternalName = TEXT("Screen");
		DisplayName = FText::FromString(TEXT("Screen"));
	}

	UFUNCTION()
	void netFunc_getSize(int& w, int& h);
	UFUNCTION()
    void netFuncMeta_getSize(FString& InternalName, FText& DisplayName, FText& Description, TArray<FString>& ParameterInternalNames, TArray<FText>& ParameterDisplayNames, TArray<FText>& ParameterDescriptions, int32& Runtime) {
		InternalName = "getSize";
		DisplayName = FText::FromString("Get Size");
		Description = FText::FromString("Returns the size of the screen in 'panels'.");
		ParameterInternalNames.Add("width");
		ParameterDisplayNames.Add(FText::FromString("Width"));
		ParameterDescriptions.Add(FText::FromString("The width of the screen."));
		ParameterInternalNames.Add("height");
		ParameterDisplayNames.Add(FText::FromString("Height"));
		ParameterDescriptions.Add(FText::FromString("The height of the screen."));
		Runtime = 2;
	}

	UFUNCTION(NetMulticast, Reliable)
	void NetMulti_OnGPUUpdate();
	
	static void SpawnComponents(TSubclassOf<UStaticMeshComponent> Class, int ScreenWidth, int ScreenHeight, UStaticMesh* MiddlePartMesh, UStaticMesh* EdgePartMesh, UStaticMesh* CornerPartMesh, AActor* Parent, USceneComponent* Attach, TArray<UStaticMeshComponent*>& OutParts);
	static void SpawnEdgeComponent(TSubclassOf<UStaticMeshComponent> Class, int x, int y, int r, UStaticMesh* EdgePartMesh, AActor* Parent, USceneComponent* Attach, int ScreenWidth, int ScreenHeight, TArray<UStaticMeshComponent*>& OutParts);
	static void SpawnCornerComponent(TSubclassOf<UStaticMeshComponent> Class, int x, int y, int r, UStaticMesh* CornerPartMesh, AActor* Parent, USceneComponent* Attach, int ScreenWidth, int ScreenHeight, TArray<UStaticMeshComponent*>& OutParts);
};
