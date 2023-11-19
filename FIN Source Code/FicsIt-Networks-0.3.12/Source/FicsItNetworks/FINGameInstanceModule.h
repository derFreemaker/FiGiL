#pragma once

#include "Module/GameInstanceModule.h"
#include "FINGameInstanceModule.generated.h"

UCLASS()
class UFINGameInstanceModule : public UGameInstanceModule {
	GENERATED_BODY()
public:
	UFINGameInstanceModule();

	// Begin UGameInstanceModule
	virtual void DispatchLifecycleEvent(ELifecyclePhase Phase) override;
	// End UGameInstanceModule
};
