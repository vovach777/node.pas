unit np.eventEmitter;
interface
  uses np.eventEmitter.TComponent, np.eventEmitter.TAnyObject, np.eventEmitter.TInterfacedObject, np.common;

  type
     TEventEmitter          = np.eventEmitter.TInterfacedObject.TEventEmitter;
     TEventEmitterAnyObject = np.eventEmitter.TAnyObject.TEventEmitter;
     TEventEmitterComponent = np.eventEmitter.TComponent.TEventEmitter;
     IEventEmitter          = np.common.IEventEmitter;
     IEventHandler          = np.common.IEventHandler;

implementation

end.