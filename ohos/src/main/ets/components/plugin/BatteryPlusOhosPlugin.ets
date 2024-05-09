import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { BusinessError } from '@ohos.base';
import EventChannel, { StreamHandler, EventSink } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import batteryInfo from '@ohos.batteryInfo';
import power from '@ohos.power';

import commonEventManager from '@ohos.commonEventManager';

/** BatteryPlusOhosPlugin **/
export default class BatteryPlusOhosPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private receiver: BatteryChargingStreamHandler | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "BatteryPlusOhosPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "dev.fluttercommunity.plus/battery");
    this.channel.setMethodCallHandler(this)
    this.eventChannel = new EventChannel(binding.getBinaryMessenger(), "dev.fluttercommunity.plus/charging");
    this.receiver = new BatteryChargingStreamHandler();
    this.eventChannel.setStreamHandler(this.receiver!);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
    if (this.eventChannel != null) {
      this.eventChannel.setStreamHandler(null);
    }
    this.receiver?.unregister();
    this.receiver = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == "getBatteryLevel") {
      result.success(batteryInfo.batterySOC)
    }
    else if (call.method == "isInBatterySaveMode") {
      let powerMode: power.DevicePowerMode = power.getPowerMode();
      result.success(powerMode == power.DevicePowerMode.MODE_POWER_SAVE || powerMode == power.DevicePowerMode.MODE_EXTREME_POWER_SAVE)
    }
    else if (call.method == "getBatteryState") {
      result.success(BatteryPlusOhosPlugin.getChargingStatus())
    }
    else {
      result.notImplemented()
    }
  }

  static getChargingStatus(): string {
    let chargingStatus: string = 'unknown';
    switch (batteryInfo.chargingStatus) {
      case batteryInfo.BatteryChargeState.FULL:
        chargingStatus = 'full';
        break;
      case batteryInfo.BatteryChargeState.NONE:
        chargingStatus = 'unknown';
        break;
      case batteryInfo.BatteryChargeState.ENABLE:
        chargingStatus = 'charging';
        break;
      case batteryInfo.BatteryChargeState.DISABLE:
        chargingStatus = 'discharging';
        break;
      default:
        break;
    }
    return chargingStatus;
  }
}


class BatteryChargingStreamHandler implements StreamHandler {
  onCancel(args: ESObject): void {
    this.unregister();
    this.events = null;
  }

  private events: EventSink | null = null;
  private subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
    events: ["COMMON_EVENT_BATTERY_CHANGED"]
  };
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;

  unregister(): void {
    if (this.subscriber != null) {
      commonEventManager.unsubscribe(this.subscriber, this.onBatteryChanged);
      this.subscriber = null;
    }
  }

  register(): void {
    try {
      this.subscriber = commonEventManager.createSubscriberSync(this.subscribeInfo);
      commonEventManager.subscribe(this.subscriber, this.onBatteryChanged);
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      console.error(`createSubscriberSync failed, code is ${err.code}, message is ${err.message}`);
    }
  }

  onBatteryChanged(): void {
    this.events?.success(BatteryPlusOhosPlugin.getChargingStatus());
  }

  onListen(args: ESObject, events: EventSink) {
    this.events = events;
    this.register();
  }
}