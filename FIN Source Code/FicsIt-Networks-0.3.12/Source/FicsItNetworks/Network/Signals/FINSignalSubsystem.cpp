#include "FINSignalSubsystem.h"

#include "Subsystem/SubsystemActorManager.h"
#include "FINSignalListener.h"
#include "Engine/Engine.h"
#include "FicsItNetworks/Network/FINHookSubsystem.h"
#include "FicsItNetworks/FicsItNetworksModule.h"

void FFINSignalListeners::AddStructReferencedObjects(FReferenceCollector& ReferenceCollector) const {
	for (const FFINNetworkTrace& Trace : Listeners) {
		Trace.AddStructReferencedObjects(ReferenceCollector);
	}
}

bool AFINSignalSubsystem::ShouldSave_Implementation() const {
	return true;
}

void AFINSignalSubsystem::PreSaveGame_Implementation(int32 saveVersion, int32 gameVersion) {
	Cleanup();
}

void AFINSignalSubsystem::PostLoadGame_Implementation(int32 saveVersion, int32 gameVersion) {
	AFINHookSubsystem* HookSubsystem = AFINHookSubsystem::GetHookSubsystem(this);
	if (HookSubsystem) for (const TPair<UObject*, FFINSignalListeners>& Sender : Listeners) {
		HookSubsystem->AttachHooks(Sender.Key);
	} else {
		UE_LOG(LogFicsItNetworks, Warning, TEXT("Hook Subsystem not found! Unable to reattach hooks!"));
	}
}

void AFINSignalSubsystem::GatherDependencies_Implementation(TArray<UObject*>& out_dependentObjects) {
	out_dependentObjects.Add(AFINHookSubsystem::GetHookSubsystem(this));
}

void AFINSignalSubsystem::Cleanup() {
	TArray<UObject*> ListenerKeys;
	Listeners.GetKeys(ListenerKeys);
	for (UObject* Sender : ListenerKeys) {
		if (!IsValid(Sender)) {
			Listeners.Remove(Sender);
		} else {
			TArray<FFINNetworkTrace>& Listen = Listeners[Sender].Listeners;
			for (int i = 0; i < Listen.Num(); ++i) {
				const FFINNetworkTrace& Listener = Listen[i];
				if (!IsValid(Listener.GetUnderlyingPtr())) {
					Listen.RemoveAt(i--);
				}
			}
			if (Listen.Num() < 1) {
				Listeners.Remove(Sender);
			}
		}
	}
}

AFINSignalSubsystem* AFINSignalSubsystem::GetSignalSubsystem(UObject* WorldContext) {
	UWorld* WorldObject = GEngine->GetWorldFromContextObjectChecked(WorldContext);
	USubsystemActorManager* SubsystemActorManager = WorldObject->GetSubsystem<USubsystemActorManager>();
	check(SubsystemActorManager);
	return SubsystemActorManager->GetSubsystemActor<AFINSignalSubsystem>();
}

void AFINSignalSubsystem::BroadcastSignal(UObject* Sender, const FFINSignalData& Signal) {
	FFINSignalListeners* ListenerList = Listeners.Find(Sender);
	if (!ListenerList) return;
	for (const FFINNetworkTrace& ReceiverTrace : ListenerList->Listeners) {
		if (&ReceiverTrace == nullptr) {
			UE_LOG(LogFicsItNetworks, Warning, TEXT("SignalSubsystem: Invalid receiver trave. Sender: %s, ListenerList: %p, Listeners.Num(): %i"), *Sender->GetName(), ListenerList, ListenerList->Listeners.Num());
			continue;
		}
		IFINSignalListener* Receiver = Cast<IFINSignalListener>(ReceiverTrace.Get());
		if (Receiver) {
			Receiver->HandleSignal(Signal, ReceiverTrace.Reverse());
		}
	}
}

void AFINSignalSubsystem::Listen(UObject* Sender, const FFINNetworkTrace& Receiver) {
	TArray<FFINNetworkTrace>& ListenerList = Listeners.FindOrAdd(Sender).Listeners;
	ListenerList.AddUnique(Receiver);
	AFINHookSubsystem::GetHookSubsystem(Sender)->AttachHooks(Sender);
}

void AFINSignalSubsystem::Ignore(UObject* Sender, UObject* Receiver) {
	FFINSignalListeners* ListenerList = Listeners.Find(Sender);
	if (!ListenerList) return;
	for (int i = 0; i < ListenerList->Listeners.Num(); ++i) {
		if (ListenerList->Listeners[i].GetUnderlyingPtr() == Receiver) {
			ListenerList->Listeners.RemoveAt(i);
			--i;
		}
	}
	if (!Sender) return;
	AFINHookSubsystem* HookSubsystem = AFINHookSubsystem::GetHookSubsystem(Sender);
	if (ListenerList->Listeners.Num() < 1 && HookSubsystem) HookSubsystem->ClearHooks(Sender);
}

void AFINSignalSubsystem::IgnoreAll(UObject* Receiver) {
	TArray<UObject*> Senders;
	Listeners.GetKeys(Senders);
	for (UObject* Sender : Senders) {
		Ignore(Sender, Receiver);
	}
}

TArray<UObject*> AFINSignalSubsystem::GetListening(UObject* Reciever) {
	TArray<UObject*> Listening;
	for (TPair<UObject*, FFINSignalListeners> Sender : Listeners) {
		if (Sender.Value.Listeners.Contains(FFINNetworkTrace(Reciever))) {
			Listening.Add(Sender.Key);
		}
	}
	return Listening;
}
