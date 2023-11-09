﻿#pragma once

#include "CoreMinimal.h"
#include "FicsItNetworks/Network/FINNetworkTrace.h"
#include "FINScreenInterface.generated.h"

UINTERFACE(Blueprintable)
class FICSITNETWORKS_API UFINScreenInterface : public UInterface {
	GENERATED_BODY()
};

class FICSITNETWORKS_API IFINScreenInterface {
	GENERATED_IINTERFACE_BODY()
	
public:
	/**
	 * Binds the screen to the given GPU.
	 * Might cause the GPU to reset and the widget to get recreated.
	 * Pass nullptr if you want to unbind the current GPU.
	 *
	 * Server Only
	 *
	 * @param[in]	gpu		the new gpu this screen should bind to.
	 */
	UFUNCTION()
	virtual void BindGPU(const FFINNetworkTrace& gpu) = 0;

	/**
	 * Returns the currently bound GPU.
	 * Nullptr if no gpu is bound.
	 *
	 * Server Only
	 *
	 * @return	the currently bound gpu.
	 */
	UFUNCTION()
	virtual FFINNetworkTrace GetGPU() const = 0;

	/**
	 * Gets called by the GPU and forces the Screen to now use the given widget.
	 *
	 * Client Only
	 *
	 * @param[in]	widget	the new widget which should get displayed.
	 */
	virtual void SetWidget(TSharedPtr<SWidget> widget) = 0;

	/**
	 * Returns the currently cached widget of the screen
	 *
	 * Client Only
	 *
	 * @return	the currently cached widget
	 */
	virtual TSharedPtr<SWidget> GetWidget() const = 0;

	/**
	 * Lets the screen to request a new widget from the gpu.
	 */
	virtual void RequestNewWidget() = 0;
};
