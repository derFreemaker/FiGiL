﻿#include "FINComputerNetworkCard.h"

#include "FicsItNetworks/Network/FINNetworkCircuit.h"
#include "FicsItNetworks/Network/Signals/FINSignalListener.h"
#include "FicsItNetworks/Reflection/FINReflection.h"

void AFINComputerNetworkCard::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const {
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	
	DOREPLIFETIME(AFINComputerNetworkCard, ID);
	DOREPLIFETIME(AFINComputerNetworkCard, Nick);
}

AFINComputerNetworkCard::AFINComputerNetworkCard() {
	PrimaryActorTick.bCanEverTick = true;
	SetActorTickEnabled(true);
}

void AFINComputerNetworkCard::BeginPlay() {
	Super::BeginPlay();

	if (HasAuthority() && !GetBlueprintDesigner()) {
		if (!bIdCreated) {
			ID = FGuid::NewGuid();
			bIdCreated = true;
		}

		// setup circuit
		if (!Circuit) {
			Circuit = GetWorld()->SpawnActor<AFINNetworkCircuit>();
			Circuit->Recalculate(this);
		}
	}
}

void AFINComputerNetworkCard::Tick(float DeltaSeconds) {
	Super::Tick(DeltaSeconds);

	HandledMessages.Empty();
}

FGuid AFINComputerNetworkCard::GetID_Implementation() const {
	return ID;
}

FString AFINComputerNetworkCard::GetNick_Implementation() const {
	return Nick;
}

void AFINComputerNetworkCard::SetNick_Implementation(const FString& nick) {
	Nick = nick;
}

bool AFINComputerNetworkCard::HasNick_Implementation(const FString& nick) {
	return HasNickByNick(nick, Execute_GetNick(this));
}

UObject* AFINComputerNetworkCard::GetInstanceRedirect_Implementation() const {
	return nullptr;
}

bool AFINComputerNetworkCard::AccessPermitted_Implementation(FGuid NewID) const {
	return NewID == FGuid() || (ConnectedComponent && NewID == IFINNetworkComponent::Execute_GetID(ConnectedComponent));
}

TSet<UObject*> AFINComputerNetworkCard::GetConnected_Implementation() const {
	TSet<UObject*> Arr;
	Arr.Add(ConnectedComponent);
	return Arr;
}

AFINNetworkCircuit* AFINComputerNetworkCard::GetCircuit_Implementation() const {
	return Circuit;
}

void AFINComputerNetworkCard::SetCircuit_Implementation(AFINNetworkCircuit* NewCircuit) {
	Circuit = NewCircuit;
}

void AFINComputerNetworkCard::NotifyNetworkUpdate_Implementation(int Type, const TSet<UObject*>& Nodes) {}

bool AFINComputerNetworkCard::IsPortOpen(int Port) {
	return OpenPorts.Contains(Port);
}

void AFINComputerNetworkCard::HandleMessage(const FGuid& InID, const FGuid& Sender, const FGuid& Receiver, int Port, const TArray<FFINAnyNetworkValue>& Data) {
	static UFINSignal* Signal = nullptr;
	if (!Signal) Signal = FFINReflection::Get()->FindClass(StaticClass())->FindFINSignal("NetworkMessage");
	{
		FScopeLock Lock(&HandledMessagesMutex);
		if (HandledMessages.Contains(InID) || !Signal) return;
		HandledMessages.Add(InID);
	}
	if (!IsPortOpen(Port)) return;
	if (Receiver.IsValid() && Receiver != ID) return;
	TArray<FFINAnyNetworkValue> Parameters = { Sender.ToString(), (FINInt)Port };
	Parameters.Append(Data);
	Signal->Trigger(this, Parameters);
}

void AFINComputerNetworkCard::SetPCINetworkConnection_Implementation(const TScriptInterface<IFINNetworkCircuitNode>& InNode) {
	ConnectedComponent = InNode.GetObject();
}

bool AFINComputerNetworkCard::CheckNetMessageData(const TArray<FFINAnyNetworkValue>& Data) {
	if (Data.Num() > 7) return false;
	for (const FFINAnyNetworkValue& Value : Data) {
		switch (Value.GetType()) {
		case FIN_OBJ:
			return false;
		case FIN_CLASS:
			return false;
		case FIN_TRACE:
			return false;
		case FIN_STRUCT:
			return false;
		case FIN_ARRAY:
			return false;
		case FIN_ANY:
			return false;
		default: ;
		}
	}
	return true;
}

void AFINComputerNetworkCard::netFunc_open(int port) {
	if (port < 0 || port > 10000) return;
	if (!OpenPorts.Contains(port)) OpenPorts.Add(port);
}

void AFINComputerNetworkCard::netFunc_close(int port) {
	OpenPorts.Remove(port);
}

void AFINComputerNetworkCard::netFunc_closeAll() {
	OpenPorts.Empty();
}

void AFINComputerNetworkCard::netFunc_send(FString receiver, int port, TArray<FFINAnyNetworkValue> args) {
	if (!CheckNetMessageData(args) || port < 0 || port > 10000) return;
	FGuid receiverID;
	FGuid::Parse(receiver, receiverID);
	if (!receiverID.IsValid()) return;
	UObject* Obj = Circuit->FindComponent(receiverID, nullptr).GetObject();
	IFINNetworkMessageInterface* NetMsgI = Cast<IFINNetworkMessageInterface>(Obj);
	FGuid MsgID = FGuid::NewGuid();
	FGuid SenderID = Execute_GetID(this);
	if (NetMsgI) {
		// send to specific component directly
		NetMsgI->HandleMessage(MsgID, SenderID, receiverID, port, args);
	} else {
		// distribute to all routers
		for (UObject* Router : Circuit->GetComponents()) {
			IFINNetworkMessageInterface* MsgI = Cast<IFINNetworkMessageInterface>(Router);
			if (!MsgI || !MsgI->IsNetworkMessageRouter()) continue;
			MsgI->HandleMessage(MsgID, SenderID, receiverID, port, args);
		}
	}
}

void AFINComputerNetworkCard::netFunc_broadcast(int port, TArray<FFINAnyNetworkValue> args) {
 	if (!CheckNetMessageData(args) || port < 0 || port > 10000) return;
	FGuid MsgID = FGuid::NewGuid();
	FGuid SenderID = Execute_GetID(this);
	for (UObject* Component : GetCircuit_Implementation()->GetComponents()) {
		IFINNetworkMessageInterface* NetMsgI = Cast<IFINNetworkMessageInterface>(Component);
		if (NetMsgI) {
			NetMsgI->HandleMessage(MsgID, SenderID, FGuid(), port, args);
		}
	}
}
