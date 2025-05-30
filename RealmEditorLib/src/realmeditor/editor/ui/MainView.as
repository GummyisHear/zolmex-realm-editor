package realmeditor.editor.ui {
import flash.desktop.NativeApplication;
import flash.display.NativeWindow;

import realmeditor.editor.actions.data.MapSelectData;

import realmeditor.editor.tools.MEEraserTool;

import realmeditor.editor.tools.METool;

import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;

import flash.events.MouseEvent;
import flash.geom.Point;
import flash.system.fscommand;

import flash.utils.getTimer;

import realmeditor.RealmEditorTestEvent;

import realmeditor.editor.AutoMapSaver;

import realmeditor.editor.MEBrush;
import realmeditor.editor.MEClipboard;
import realmeditor.editor.MEDrawType;
import realmeditor.editor.MEEvent;
import flash.display.DisplayObject;

import realmeditor.editor.MapData;
import realmeditor.editor.MapHistory;
import realmeditor.editor.MapTileData;
import realmeditor.editor.TimeControl;
import realmeditor.editor.ToolSwitchEvent;
import realmeditor.editor.actions.MapEditAction;
import realmeditor.editor.tools.MESelectTool;
import realmeditor.editor.ui.elements.MultiOptionalSwitch;
import realmeditor.editor.ui.elements.SimpleCheckBox;
import realmeditor.editor.ui.elements.SimpleTextButton;
import realmeditor.editor.ui.elements.SimpleTextInput;
import realmeditor.editor.ui.embed.Background;
import realmeditor.util.IntPoint;
public class MainView extends Sprite {

    private static const MAX_ZOOM:Number = 1000.0;
    public static var Instance:MainView;
    public static var Main:Sprite;
    public static var StageWidth:int = 800;
    public static var StageHeight:int = 600;
    public static var ScaleX:Number;
    public static var ScaleY:Number;

    private var mapSelector:MapSelectorView;
    public var mapViewContainer:MapViewContainer;
    public var mapView:MapView;
    private var mapData:MapData;
    private var nextMapId:int;

    private var background:Background;
    private var loadButton:SimpleTextButton;
    private var newButton:SimpleTextButton;
    private var saveButton:SimpleTextButton;
    private var backButton:SimpleTextButton; // Back to title screen (in embedded mode)
    private var saveWmapButton:SimpleTextButton;
    private var testMapButton:SimpleTextButton;
    private var mapCreateWindow:CreateMapWindow;
    private var closePrompt:ClosePromptWindow;
    private var mapInfoPanel:MapInfoPanel;
    private var mapDimensionsWindow:MapDimensionsWindow;
    private var selectionInfoPanel:SelectionInfoPanel;
    private var brushOptions:BrushOptions;
    private var tileHotkeys:TileHotkeys;

    public var inputHandler:MapInputHandler;
    public var notifications:NotificationView;
    private var zoomInput:SimpleTextInput;
    private var toolBoxBackground:Shape;
    private var tileInfoPanel:TileInfoPanel;
    private var gridCheckbox:SimpleCheckBox;
    private var autoSaveCheckbox:SimpleCheckBox;
    private var drawTypeSwitch:MultiOptionalSwitch;
    private var editNameView:EditTileNameView;
    private var objectFilterView:ObjectFilterOptionsView;
    private var debugView:DebugView;

    private var drawElementsList:MapDrawElementListView;
    private var toolBar:MapToolbar;

    public var userBrush:MEBrush;
    public var selectedTool:METool;
    private var lastMousePos:Point;
    private var previousTool:METool;
    private var clipBoard:MEClipboard;
    public var timeControl:TimeControl; // Controls actions done/undone in each map

    private var lastUpdate:int;
    private var autoSaver:AutoMapSaver;
    private var window:NativeWindow;

    public var testMode:Boolean;

    public function MainView(main:Sprite, embedded:Boolean) {
        Instance = this;
        Main = main;
        Main.stage.addEventListener(Event.RESIZE, this.onStageResize);
        StageWidth = Main.stage.stageWidth;
        StageHeight = Main.stage.stageHeight;
        ScaleX = Main.stage.stageWidth / 800;
        ScaleY = Main.stage.stageHeight / 600;

        this.userBrush = new MEBrush(this, MEDrawType.GROUND, 0);
        this.clipBoard = new MEClipboard();
        this.timeControl = new TimeControl();
        this.selectedTool = new MESelectTool(this);
        this.autoSaver = new AutoMapSaver();
        this.window = main.stage.nativeWindow;

        this.background = new Background();
        addChild(this.background);

        this.mapViewContainer = new MapViewContainer();
        this.mapViewContainer.addChild(this.background);
        addChild(this.mapViewContainer);

        this.setupInput();

        this.toolBoxBackground = new Shape();
        this.toolBoxBackground.filters = Constants.SHADOW_FILTER_1;
        addChild(this.toolBoxBackground);

        this.zoomInput = new SimpleTextInput("Zoom", false, "100", 18, 0xFFFFFF, 15, 0xEAEAEA, true);
        this.zoomInput.inputText.restrict = "0-9";
        this.zoomInput.inputText.maxChars = 3;
        this.zoomInput.inputText.addEventListener(Event.CHANGE, this.onZoomInputChange);
        addChild(this.zoomInput);

        this.gridCheckbox = new SimpleCheckBox("Grid", false);
        this.gridCheckbox.addEventListener(Event.CHANGE, this.onGridClick);
        addChild(this.gridCheckbox);

        this.autoSaveCheckbox = new SimpleCheckBox("Autosave", true);
        this.autoSaveCheckbox.addEventListener(Event.CHANGE, this.onAutoSaveClick);
        addChild(this.autoSaveCheckbox);

        this.drawTypeSwitch = new MultiOptionalSwitch();
        this.drawTypeSwitch.addOption("Ground");
        this.drawTypeSwitch.addOption("Objects");
        this.drawTypeSwitch.addOption("Regions");
        this.drawTypeSwitch.addEventListener(MEEvent.OPTION_SWITCH, this.onDrawTypeSwitch);
        addChild(this.drawTypeSwitch);

        var g:Graphics = this.toolBoxBackground.graphics;
        g.beginFill(Constants.BACK_COLOR_2, 0.8);
        g.drawRoundRect(0, 0,
                this.autoSaveCheckbox.width + 10, // Add here all of the things that are supposed to go inside of the toolbox
                this.zoomInput.height + this.gridCheckbox.height + this.autoSaveCheckbox.height + this.drawTypeSwitch.height + 32,
                10, 10);
        g.endFill();

        this.tileInfoPanel = new TileInfoPanel();
        this.tileInfoPanel.visible = false;
        addChild(this.tileInfoPanel);

        this.drawElementsList = new MapDrawElementListView();
        this.drawElementsList.setContent(MEDrawType.GROUND);
        this.drawElementsList.addEventListener(Event.SELECT, this.onDrawElementSelected);
        addChild(this.drawElementsList);

        this.toolBar = new MapToolbar(this);
        addChild(this.toolBar);

        this.loadButton = new SimpleTextButton("Load");
        this.loadButton.addEventListener(MouseEvent.CLICK, this.onLoadClick);
        addChild(this.loadButton);

        this.newButton = new SimpleTextButton("New");
        this.newButton.addEventListener(MouseEvent.CLICK, this.onNewClick);
        addChild(this.newButton);

        this.saveButton = new SimpleTextButton("Save JSON");
        this.saveButton.addEventListener(MouseEvent.CLICK, this.onSaveClick);
        addChild(this.saveButton);

        if (embedded) {
            this.backButton = new SimpleTextButton("Back");
            this.backButton.addEventListener(MouseEvent.CLICK, this.onBackClick);
            addChild(this.backButton);
        }

        this.saveWmapButton = new SimpleTextButton("Save Wmap");
        this.saveWmapButton.addEventListener(MouseEvent.CLICK, this.onSaveWmapClick);
        addChild(this.saveWmapButton);

        this.testMapButton = new SimpleTextButton("Test");
        this.testMapButton.addEventListener(MouseEvent.CLICK, this.onTestMapClick);
        addChild(this.testMapButton);

        this.mapSelector = new MapSelectorView();
        this.mapSelector.addEventListener(MEEvent.MAP_SELECT, this.onMapSelected);
        this.mapSelector.addEventListener(MEEvent.MAP_CLOSED, this.onMapClosed);
        addChild(this.mapSelector);

        this.objectFilterView = new ObjectFilterOptionsView(this.drawElementsList);
        addChild(this.objectFilterView);

        this.mapInfoPanel = new MapInfoPanel();
        this.mapInfoPanel.addEventListener(MouseEvent.CLICK, onMapDimensionsClick);
        this.mapInfoPanel.visible = false;
        addChild(this.mapInfoPanel);

        this.selectionInfoPanel = new SelectionInfoPanel();
        this.selectionInfoPanel.visible = false;
        addChild(this.selectionInfoPanel);

        this.notifications = new NotificationView();
        addChild(this.notifications);

        this.brushOptions = new BrushOptions(this);
        this.addEventListener(MEEvent.BRUSH_CHANGED, this.onBrushChanged);
        this.brushOptions.addEventListener(Event.CHANGE, this.updateBrushOptionsPosition);
        addChild(this.brushOptions);

        this.tileHotkeys = new TileHotkeys();
        this.tileHotkeys.addEventListener(MEEvent.TILE_HOTKEY_SWITCH, this.onTileHotkey);
        addChild(this.tileHotkeys);

        Main.stage.addEventListener(Event.ENTER_FRAME, this.update);
        Main.stage.addEventListener(MouseEvent.MOUSE_WHEEL, this.onMouseWheel);
        Main.stage.addEventListener(Event.RESIZE, this.onStageResize);
        Main.stage.addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
        this.addEventListener(MEEvent.EXIT_EDITOR, this.onRemovedFromStage);
        this.window.addEventListener(Event.CLOSING, this.onExiting); // Closing the window

        this.updateScale();
        this.updatePositions();
    }

    private function setupInput():void {
        this.inputHandler = new MapInputHandler(this);
        this.inputHandler.addEventListener(MEEvent.GRID_ENABLE, this.onGridEnable);
        this.inputHandler.addEventListener(MEEvent.TILE_CLICK, this.onTileClick);
        this.inputHandler.addEventListener(MEEvent.MOUSE_DRAG, this.onMouseDrag);
        this.inputHandler.addEventListener(MEEvent.MOUSE_DRAG_END, this.onMouseDragEnd);
        this.inputHandler.addEventListener(MEEvent.MIDDLE_MOUSE_DRAG, this.onMiddleMouseDrag);
        this.inputHandler.addEventListener(MEEvent.CTRL_MOUSE_DRAG, this.onCtrlMouseDrag);
        this.inputHandler.addEventListener(MEEvent.SHIFT_MOUSE_DRAG, this.onShiftMouseDrag);
        this.inputHandler.addEventListener(MEEvent.MIDDLE_MOUSE_DRAG_END, this.onMiddleMouseDragEnd);
        this.inputHandler.addEventListener(MouseEvent.MOUSE_MOVE, this.onMouseMoved);
        this.inputHandler.addEventListener(MEEvent.TOOL_SWITCH, this.onToolSwitch);
        this.inputHandler.addEventListener(MEEvent.TILE_HOTKEY_SWITCH, this.onTileHotkey);
        this.inputHandler.addEventListener(MEEvent.UNDO, this.onUndoAction);
        this.inputHandler.addEventListener(MEEvent.REDO, this.onRedoAction);
        this.inputHandler.addEventListener(MEEvent.DRAW_TYPE_SWITCH, this.onDrawTypeSwitchKey);
        this.inputHandler.addEventListener(MEEvent.COPY, this.onCopy);
        this.inputHandler.addEventListener(MEEvent.PASTE, this.onPaste);
        this.inputHandler.addEventListener(MEEvent.CLEAR_SELECTION, this.onClearSelection);
        this.inputHandler.addEventListener(MEEvent.MOVE_SELECTION_UP, this.onMoveSelectionUp);
        this.inputHandler.addEventListener(MEEvent.MOVE_SELECTION_DOWN, this.onMoveSelectionDown);
        this.inputHandler.addEventListener(MEEvent.MOVE_SELECTION_LEFT, this.onMoveSelectionLeft);
        this.inputHandler.addEventListener(MEEvent.MOVE_SELECTION_RIGHT, this.onMoveSelectionRight);
        this.inputHandler.addEventListener(MEEvent.TOGGLE_DEBUG, this.onToggleDebug);
        this.inputHandler.addEventListener(MEEvent.DELETE_SELECTION, this.onDeleteSelection);
    }

    private function updateScale():void {
        this.background.scaleX = ScaleX;
        this.background.scaleY = ScaleY;
    }

    public function updatePositions():void {
        this.notifications.updatePosition();

        this.loadButton.x = 15;
        this.loadButton.y = 15;

        this.newButton.x = this.loadButton.x + this.loadButton.width + 10;
        this.newButton.y = this.loadButton.y;

        this.saveButton.x = this.newButton.x + this.newButton.width + 10;
        this.saveButton.y = this.loadButton.y;

        if (this.backButton != null) {
            this.backButton.x = StageWidth - this.backButton.width - 10;
            this.backButton.y = this.loadButton.y;
        }

        this.saveWmapButton.x = this.saveButton.x + this.saveButton.width + 10;
        this.saveWmapButton.y = this.loadButton.y;

        this.testMapButton.x = this.saveWmapButton.x + this.saveWmapButton.width + 10;
        this.testMapButton.y = this.loadButton.y;

        this.mapSelector.x = this.loadButton.x;
        this.mapSelector.y = this.loadButton.y + this.loadButton.height + 10;

        this.mapInfoPanel.x = 19;
        this.mapInfoPanel.y = StageHeight - this.mapInfoPanel.height - 15;

        this.toolBoxBackground.x = 15;
        this.toolBoxBackground.y = (StageHeight - this.toolBoxBackground.height) / 2;

        this.zoomInput.x = this.toolBoxBackground.x + 5;
        this.zoomInput.y = this.toolBoxBackground.y + 7.5;

        this.gridCheckbox.x = this.zoomInput.x;
        this.gridCheckbox.y = this.zoomInput.y + this.zoomInput.height + 6;

        this.autoSaveCheckbox.x = this.zoomInput.x;
        this.autoSaveCheckbox.y = this.gridCheckbox.y + this.gridCheckbox.height + 6;

        this.drawTypeSwitch.x = this.zoomInput.x;
        this.drawTypeSwitch.y = this.autoSaveCheckbox.y + this.autoSaveCheckbox.height + 6;

        this.drawElementsList.x = StageWidth - MapDrawElementListView.WIDTH - 15;
        if (this.backButton != null) {
            this.drawElementsList.y = this.backButton.y + this.backButton.height + 15;
        } else {
            this.drawElementsList.y = 15;
        }

        this.tileInfoPanel.x = this.drawElementsList.x - this.tileInfoPanel.width - 15;
        this.tileInfoPanel.y = StageHeight - this.tileInfoPanel.height - 15;

        this.selectionInfoPanel.x = this.tileInfoPanel.x - this.selectionInfoPanel.width - 5;
        this.selectionInfoPanel.y = StageHeight - this.selectionInfoPanel.height - 15;

        this.toolBar.x = this.drawElementsList.x - this.toolBar.width - 8;
        this.toolBar.y = (StageHeight - this.toolBar.height) / 2;

        this.objectFilterView.x = this.drawElementsList.x - 20;
        this.objectFilterView.y = this.drawElementsList.y;

        this.updateBrushOptionsPosition(null);

        this.tileHotkeys.x = this.drawElementsList.x - this.tileHotkeys.width - 8;
        this.tileHotkeys.y = this.toolBar.y - this.tileHotkeys.height - 8;

        if (this.mapView) {
            this.mapView.x = (StageWidth - (this.mapData.mapWidth * TileMapView.TILE_SIZE) * this.mapView.scaleX) / 2;
            this.mapView.y = (StageHeight - (this.mapData.mapHeight * TileMapView.TILE_SIZE) * this.mapView.scaleY) / 2;
            this.mapView.x += this.mapView.mapOffset.x_ * this.mapView.zoomLevel / MAX_ZOOM;
            this.mapView.y += this.mapView.mapOffset.y_ * this.mapView.zoomLevel / MAX_ZOOM;
        }

        if (this.mapCreateWindow != null && this.mapCreateWindow.visible) {
            this.mapCreateWindow.x = (StageWidth - this.mapCreateWindow.width) / 2;
            this.mapCreateWindow.y = (StageHeight - this.mapCreateWindow.height) / 2;
        }

        if (this.editNameView != null && this.editNameView.visible) {
            this.editNameView.x = (StageWidth - this.editNameView.width) / 2;
            this.editNameView.y = (StageHeight - this.editNameView.height) / 2;
        }

        if (this.debugView != null && this.debugView.visible) {
            this.debugView.x = 10;
            this.debugView.y = StageHeight - this.debugView.height - 10;
        }

        if (this.closePrompt != null && this.closePrompt.visible) {
            this.closePrompt.x = (StageWidth - this.closePrompt.width) / 2;
            this.closePrompt.y = (StageHeight - this.closePrompt.height) / 2;
        }

        if (this.mapDimensionsWindow != null && this.mapDimensionsWindow.visible) {
            this.mapDimensionsWindow.x = (StageWidth - this.mapDimensionsWindow.width) / 2;
            this.mapDimensionsWindow.y = (StageHeight - this.mapDimensionsWindow.height) / 2;
        }
    }

    private function onMouseWheel(e:MouseEvent):void {
        if (this.mapView == null || this.testMode) {
            return;
        }

        if (e.ctrlKey && (this.selectedTool.id == METool.PENCIL_ID || this.selectedTool.id == METool.ERASER_ID || this.selectedTool.id == METool.SHAPE_ID)) { // We're increasing/decreasing the brush size
            var val:int = Math.min(Math.max(int(Math.ceil(e.delta)), -1), 1);
            this.userBrush.setSize(this.userBrush.size + val);
            if (this.userBrush.size < 0) {
                this.userBrush.setSize(0);
            }
            return;
        }

        var zoomLevel:int = this.mapView.zoomLevel + (this.mapView.zoomLevel / e.delta + 1); // + 1 for divisions that result in less than 1
        zoomLevel = Math.max(1, Math.min(zoomLevel, MAX_ZOOM));

        if (this.mapView.zoomLevel != zoomLevel) {
            this.mapView.zoomLevel = zoomLevel;
            var deltaX:Number = StageWidth / 2 - Main.stage.mouseX; // Figure out how far from the middle the mouse is
            var deltaY:Number = StageHeight / 2 - Main.stage.mouseY;
            if (e.delta < 0) { // Invert the order if we're zooming out
                deltaX *= -1;
                deltaY *= -1;
            }

            var zoom:Number = Math.max(1, Math.min(MAX_ZOOM, MAX_ZOOM / this.mapView.zoomLevel));
            this.mapView.mapOffset.x_ += deltaX * (zoom * 0.5);
            this.mapView.mapOffset.y_ += deltaY * (zoom * 0.5);

            this.updateZoomLevel();
        }
    }

    private function onStageResize(e:Event):void {
        StageWidth = Main.stage.stageWidth;
        StageHeight = Main.stage.stageHeight;
        ScaleX = Main.stage.stageWidth / 800;
        ScaleY = Main.stage.stageHeight / 600;

        this.updateScale();
        this.updatePositions();

        this.drawElementsList.onScreenResize();
    }

    private function onRemovedFromStage(e:Event):void {
        this.inputHandler.clear();
        Main.stage.removeEventListener(Event.ENTER_FRAME, this.update);
        Main.stage.removeEventListener(MouseEvent.MOUSE_WHEEL, this.onMouseWheel);
        Main.stage.removeEventListener(Event.RESIZE, this.onStageResize);
        Main.stage.removeEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
        this.window.removeEventListener(Event.CLOSING, this.onExiting);
    }

    private function update(e:Event):void { // Runs every frame
        if (this.testMode) {
            if (this.visible) { // If we are visible then that means we're no longer in test mode
                this.testMode = false;
            } else {
                return;
            }
        }

        var time:int = getTimer();
        var deltaTime:int = time - this.lastUpdate;
        this.lastUpdate = time;

        if (this.debugView != null && this.debugView.visible) {
            this.debugView.updateStats(time, deltaTime);
        }

        if (this.mapData != null) {
            this.autoSaver.trySaveMap(this.mapData, deltaTime);
        }
    }

    private static function closeWindow():void {
        fscommand("quit"); // For Flash
        NativeApplication.nativeApplication.exit(); // For AIR
    }

    private function onExiting(e:Event):void {
        e.preventDefault();
        var unsavedChanges:Boolean = false;
        for each (var view:MapView in this.mapViewContainer.maps) { // Find out if we have unsaved changes
            if (!view.mapData.savedChanges) {
                unsavedChanges = true;
                break;
            }
        }

        if (!unsavedChanges) {
            onExit(null);
            return;
        }

        if (this.closePrompt == null) {
            this.closePrompt = new ClosePromptWindow();
            this.closePrompt.x = (StageWidth - this.closePrompt.width) / 2;
            this.closePrompt.y = (StageHeight - this.closePrompt.height) / 2;
            this.closePrompt.addEventListener(MEEvent.CLOSE_NO_SAVE, onExit);
            addChild(this.closePrompt);
        } else {
            this.closePrompt.visible = true;
        }
        this.updatePositions();
    }

    private static function onExit(e:Event):void {
        closeWindow();
    }

    private function onLoadClick(e:Event):void {
        var newData:MapData = new MapData();
        var newMap:MapView = new MapView(this.nextMapId, newData);
        this.nextMapId++;

        this.mapView = newMap;
        this.mapData = newData;
        this.mapData.addEventListener(MEEvent.MAP_LOAD_BEGIN, this.onMapLoadBegin);
        this.mapData.addEventListener(MEEvent.MAP_LOAD_END, this.onMapLoadEnd);

        this.mapData.load(newMap.tileMap);
    }

    private function onNewClick(e:Event):void {
        if (this.mapCreateWindow == null) {
            this.mapCreateWindow = new CreateMapWindow(); // Window where user inputs name, width and height of the map
            this.mapCreateWindow.x = (StageWidth - this.mapCreateWindow.width) / 2;
            this.mapCreateWindow.y = (StageHeight - this.mapCreateWindow.height) / 2;
            this.mapCreateWindow.addEventListener(MEEvent.MAP_CREATE, this.onMapCreate); // Dispatched when user clicks OK
            addChild(this.mapCreateWindow);
        } else {
            this.mapCreateWindow.visible = true;
        }
        this.updatePositions();
    }

    private function onMapCreate(e:Event):void {
        var newData:MapData = new MapData();
        var newMap:MapView = new MapView(this.nextMapId, newData);
        this.nextMapId++;

        this.mapView = newMap;
        this.mapData = newData;
        this.mapData.addEventListener(MEEvent.MAP_LOAD_BEGIN, this.onMapLoadBegin);
        this.mapData.addEventListener(MEEvent.MAP_LOAD_END, this.onMapLoadEnd);

        newData.newMap(newMap.tileMap, this.mapCreateWindow.mapName, this.mapCreateWindow.mapWidth, this.mapCreateWindow.mapHeight);
    }

    private function onMapSelected(e:Event):void {
        this.mapView = this.mapViewContainer.viewMap(this.mapSelector.selectedMap);
        this.mapData = this.mapView.mapData;

        this.updateZoomLevel();
        this.gridCheckbox.setValue(this.mapView.gridEnabled);
        this.mapInfoPanel.visible = true;
        this.mapInfoPanel.setInfo(this.mapData.mapWidth, this.mapData.mapHeight);
    }

    private function onMapClosed(e:MapClosedEvent):void {
        this.mapViewContainer.trySaveMap(e.mapId);
        this.mapViewContainer.removeMapView(e.mapId);
        this.timeControl.eraseHistory(e.mapId);

        var nextId:int = this.mapSelector.selectedMap - 1 < 0 ? 0 : this.mapSelector.selectedMap - 1;
        this.mapSelector.selectMap(nextId);

        this.mapView = this.mapViewContainer.viewMap(nextId);
        this.mapInfoPanel.visible = false;

        var mapWidth:int = 0;
        var mapHeight:int = 0;
        if (this.mapView) {
            this.mapData = this.mapView.mapData;
            mapWidth = this.mapData.mapWidth;
            mapHeight = this.mapData.mapHeight;

            this.updateZoomLevel();
            this.gridCheckbox.setValue(this.mapView.gridEnabled);
            this.mapInfoPanel.visible = true;
            this.mapInfoPanel.setInfo(mapWidth, mapHeight);
        }
    }

    private function onSaveClick(e:Event):void {
        if (this.mapData != null) {
            this.mapData.addEventListener(MEEvent.MAP_SAVED, this.onJsonSaved);
            this.mapData.save(false);
        }
    }

    private function onBackClick(e:Event):void {
        this.inputHandler.clear();
        parent.removeChild(this);
    }

    private function onSaveWmapClick(e:Event):void {
        if (this.mapData != null) {
            this.mapData.addEventListener(MEEvent.MAP_SAVED, this.onWmapSaved);
            this.mapData.save(true);
        }
    }

    private function onTestMapClick(e:Event):void {
        if (this.mapData != null) {
            var json:String = this.mapData.getMapJsonString();
            dispatchEvent(new RealmEditorTestEvent(json));
            this.testMode = true;
        }
    }

    private function onJsonSaved(e:Event):void {
        this.mapData.removeEventListener(MEEvent.MAP_SAVED, this.onJsonSaved);
        this.notifications.showNotification("Map saved in JSON format!");
    }

    private function onWmapSaved(e:Event):void {
        this.mapData.removeEventListener(MEEvent.MAP_SAVED, this.onWmapSaved);
        this.notifications.showNotification("Map saved in WMap format!");
    }

    private function onMapLoadBegin(e:Event):void {
        this.mapData.removeEventListener(MEEvent.MAP_LOAD_BEGIN, this.onMapLoadBegin);

        this.mapView.onMapLoadBegin();
        this.updatePositions();
    }

    private function onMapLoadEnd(e:Event):void {
        this.mapData.removeEventListener(MEEvent.MAP_LOAD_END, this.onMapLoadEnd);

        this.mapView.onMapLoadEnd();

        this.updateZoomLevel();

        var mapId:int = this.mapViewContainer.addMapView(this.mapView);
        this.mapSelector.addMap(mapId, this.mapData.mapName);
        this.mapSelector.selectMap(mapId);

        this.mapViewContainer.viewMap(mapId);
        this.timeControl.createHistory(this.mapView.id);
        this.mapInfoPanel.visible = true;
        this.mapInfoPanel.setInfo(this.mapData.mapWidth, this.mapData.mapHeight);
    }

    private function onGridClick(e:Event):void {
        if (this.mapView) {
            this.mapView.toggleGrid();
        }
    }

    private function onAutoSaveClick(e:Event):void {
        this.autoSaver.disabled = !this.autoSaver.disabled;
    }

    private function onGridEnable(e:Event):void {
        if (this.mapView) {
            var value:Boolean = this.mapView.toggleGrid();
            this.gridCheckbox.setValue(value);
        }
    }

    private function onZoomInputChange(e:Event):void {
        var zoomLevel:int = int(this.zoomInput.inputText.text);
        if (this.mapView.zoomLevel == zoomLevel) {
            return;
        }

        this.mapView.zoomLevel = zoomLevel;
        this.updateZoomLevel();
    }

    private function updateZoomLevel():void {
        this.zoomInput.inputText.setText(this.mapView.zoomLevel.toString());

        if (this.mapView) {
            this.mapView.scaleX = this.mapView.zoomLevel / 100;
            this.mapView.scaleY = this.mapView.zoomLevel / 100;
            if (this.mapView.scaleX < 0.01 || this.mapView.scaleY < 0.01) {
                this.mapView.scaleX = 0.01;
                this.mapView.scaleY = 0.01;
            }

            this.updatePositions();
        }
    }

    private function onMouseDrag(e:Event):void {
        var tilePos:IntPoint = getMouseTilePosition();
        if (this.mapView == null) {
            return;
        }

        this.selectedTool.mouseDrag(tilePos, this.timeControl.getHistory(this.mapView.id));
    }

    private function onMiddleMouseDrag(e:Event):void {
        if (this.lastMousePos == null) {
            this.lastMousePos = new Point(Main.stage.mouseX, Main.stage.mouseY);
        }

        this.dragMap();
    }

    private function onCtrlMouseDrag(e:Event):void {
        if (this.lastMousePos == null) {
            this.lastMousePos = new Point(Main.stage.mouseX, Main.stage.mouseY);
        }

        this.dragMap();
    }

    private function onShiftMouseDrag(e:Event):void {
        var tilePos:IntPoint = this.getMouseTilePosition();
        if (this.mapView == null) {
            return;
        }

        if (this.selectedTool.id != METool.SELECT_ID) {
            this.previousTool = this.selectedTool;
            onToolSwitch(new ToolSwitchEvent(METool.SELECT_ID));
        }

        this.selectedTool.mouseDrag(tilePos, this.timeControl.getHistory(this.mapView.id));
    }

    private function dragMap():void {
        var deltaX:Number = Main.stage.mouseX - this.lastMousePos.x;
        var deltaY:Number = Main.stage.mouseY - this.lastMousePos.y;
        var zoom:Number = Math.max(1, Math.min(MAX_ZOOM, MAX_ZOOM / this.mapView.zoomLevel));
        this.mapView.mapOffset.x_ += deltaX * zoom;
        this.mapView.mapOffset.y_ += deltaY * zoom;
        this.lastMousePos.x = Main.stage.mouseX;
        this.lastMousePos.y = Main.stage.mouseY;
        this.updatePositions();
    }

    private function onMouseDragEnd(e:Event):void {
        var tilePos:IntPoint = this.getMouseTilePosition();
        if (this.mapView == null) {
            return;
        }

        this.selectedTool.mouseDragEnd(tilePos, this.timeControl.getHistory(this.mapView.id));
        this.lastMousePos = null;
        if (this.previousTool != null) {
            this.onToolSwitch(new ToolSwitchEvent(this.previousTool.id));
            this.previousTool = null;
        }
    }

    private function onMiddleMouseDragEnd(e:Event):void {
        this.lastMousePos = null;
    }

    private function onTileClick(e:Event):void { // Perform select/draw/erase actions here
        var tilePos:IntPoint = this.getMouseTilePosition();
        if (this.mapView == null) {
            return;
        }

        if ((this.mapDimensionsWindow != null && this.mapDimensionsWindow.visible) ||
                (this.mapCreateWindow != null && this.mapCreateWindow.visible)){
            return;
        }

        this.selectedTool.tileClick(tilePos, this.timeControl.getHistory(this.mapView.id));
    }

    public function showEditNameView(x:int, y:int, objName:String):void {
        if (this.editNameView == null) {
            this.editNameView = new EditTileNameView(x, y, objName);
            this.editNameView.x = (StageWidth - this.editNameView.width) / 2;
            this.editNameView.y = (StageHeight - this.editNameView.height) / 2;
            this.editNameView.addEventListener(MEEvent.EDIT_OBJ_NAME, this.onEditName);
            addChild(this.editNameView);
        } else {
            this.editNameView.showNew(x, y, objName);
        }
        this.updatePositions();
    }

    private function onEditName(e:Event):void {
        var mapX:int = this.editNameView.tileX;
        var mapY:int = this.editNameView.tileY;
        var history:MapHistory = this.timeControl.getHistory(this.mapView.id);
        var prevData:MapTileData = this.mapView.tileMap.getTileData(mapX, mapY);
        if (prevData.objType == 0) {
            return;
        }

        history.record(new MapEditAction(mapX, mapY, prevData.objCfg, this.editNameView.objName));
        this.mapView.editTileObjCfg(mapX, mapY, this.editNameView.objName);
    }

    private function onMouseMoved(e:Event):void {
        var tilePos:IntPoint = this.getMouseTilePosition();
        if (this.mapView == null) {
            return;
        }

        this.updateSelectionPanel(this.mapView.selection);

        if (tilePos == null) {
            this.tileInfoPanel.visible = false;
            return;
        }

        this.updateTileInfoPanel(tilePos);

        this.mapView.hideOverlays();

        this.selectedTool.mouseMoved(tilePos, this.timeControl.getHistory(this.mapView.id));
    }

    private function updateTileInfoPanel(tilePos:IntPoint):void {
        var tileData:MapTileData = this.mapView.tileMap.getTileData(tilePos.x_, tilePos.y_);
        if (tileData == null) {
            this.tileInfoPanel.visible = false;
            return;
        }

        this.tileInfoPanel.visible = true;
        this.tileInfoPanel.setInfo(tilePos.x_, tilePos.y_, tileData);
        this.updatePositions();
    }

    private function updateSelectionPanel(selection:MapSelectData):void {
        if (selection == MapView.EMPTY_SELECTION) {
            this.selectionInfoPanel.visible = false;
            return;
        }
        this.selectionInfoPanel.visible = true;
        this.selectionInfoPanel.setInfo(selection);
    }

    private function getMouseTilePosition():IntPoint { // Not to handle null value
        if (this.mapView == null) {
            return null;
        }

        var mouseX:Number = Main.stage.mouseX;
        var mouseY:Number = Main.stage.mouseY;
        var x:int = (mouseX - this.mapView.x) / (TileMapView.TILE_SIZE * this.mapView.scaleX);
        var y:int = (mouseY - this.mapView.y) / (TileMapView.TILE_SIZE * this.mapView.scaleY);
        if (x < 0 || y < 0 || x >= this.mapData.mapWidth || y >= this.mapData.mapHeight) {
            return null;
        }
        return new IntPoint(x, y);
    }

    public function onToolSwitch(e:ToolSwitchEvent):void {
        this.setSelectedTool(e.toolId);
        this.toolBar.setSelected(e.toolId);
        this.brushOptions.onToolChanged(this.selectedTool);
        this.userBrush.setBrushShape(0);
        this.updatePositions();
    }

    public function setSelectedTool(toolId:int):void {
        this.lastMousePos = null;

        this.selectedTool.reset(); // Reset tool data
        this.selectedTool = METool.GetTool(toolId, this);

        if (this.mapView == null) {
            return;
        }

        if (toolId != METool.SELECT_ID) { // Clear highlighted tile
            this.mapView.highlightTile(-1, -1);
        }

        var tilePos:IntPoint = this.getMouseTilePosition();
        if (this.mapView == null) {
            return;
        }

        this.mapView.hideOverlays();
        this.selectedTool.init(tilePos, this.timeControl.getHistory(this.mapView.id));
    }

    private function onUndoAction(e:Event):void {
        if (this.mapView == null) {
            return;
        }

        this.timeControl.undoLastAction(this.mapView.id); // Undo last action done in the current map
        this.notifications.showNotification("Undone", 18, 1);
    }

    private function onRedoAction(e:Event):void {
        if (this.mapView == null) {
            return;
        }

        this.timeControl.redoLastUndoneAction(this.mapView.id); // Redo last undone action in the current map
        this.notifications.showNotification("Redone", 18, 1);
    }

    private function onDrawTypeSwitch(e:Event):void {
        this.userBrush.elementType = this.drawTypeSwitch.selected;

        this.drawElementsList.resetFilters();
        this.drawElementsList.setContent(this.userBrush.elementType);
        this.updateDrawElements();
    }

    public function updateDrawElements():void {
        switch (this.userBrush.elementType) {
            case MEDrawType.GROUND:
                this.drawElementsList.setSelected(this.userBrush.groundType);
                break;
            case MEDrawType.OBJECTS:
                this.drawElementsList.setSelected(this.userBrush.objType);
                break;
            case MEDrawType.REGIONS:
                this.drawElementsList.setSelected(this.userBrush.regType);
                break;
        }
    }

    private function onDrawTypeSwitchKey(e:Event):void {
        this.drawTypeSwitch.selectNext(); // The switch will dispatch an OPTION_SWITCH event and we'll handle that
    }

    private function onDrawElementSelected(e:Event):void {
        var elementType:int = this.drawElementsList.selectedElement == null ? -1 : this.drawElementsList.selectedElement.elementType;
        switch (this.userBrush.elementType) {
            case MEDrawType.GROUND:
                this.userBrush.setGroundType(elementType);
                break;
            case MEDrawType.OBJECTS:
                this.userBrush.setObjectType(elementType);
                break;
            case MEDrawType.REGIONS:
                this.userBrush.setRegionType(elementType);
                break;
        }

        var tilePos:IntPoint = this.getMouseTilePosition();
        if (tilePos == null) {
            return;
        }

        this.mapView.drawBrushTiles(tilePos.x_, tilePos.y_, this.userBrush);
    }

    private function onCopy(e:Event):void {
        if (this.mapView == null) {
            return;
        }

        this.clipBoard.clear();
        this.mapView.copySelectionToClipboard(this.clipBoard);
    }

    private function onPaste(e:Event):void {
        if (this.mapView == null) {
            return;
        }

        var tilePos:IntPoint = this.getMouseTilePosition();
        if (tilePos == null) {
            return;
        }

        this.mapView.pasteFromClipboard(this.clipBoard, tilePos.x_, tilePos.y_, this.timeControl.getHistory(this.mapView.id));
    }

    private function onClearSelection(e:Event):void {
        if (this.selectedTool.id == METool.SELECT_ID) {
            this.selectedTool.reset();
        }

        var history:MapHistory = this.timeControl.getHistory(this.mapView.id);
        this.mapView.recordSelectionClear(history);
        this.mapView.clearTileSelection();
    }

    private function onMoveSelectionUp(e:Event):void {
        if (this.mapView == null || this.selectedTool.id != METool.SELECT_ID) {
            return;
        }

        var selectTool:MESelectTool = METool.GetTool(METool.SELECT_ID, this) as MESelectTool;
        selectTool.dragSelection(0, -1, this.timeControl.getHistory(this.mapView.id));
    }

    private function onMoveSelectionDown(e:Event):void {
        if (this.mapView == null || this.selectedTool.id != METool.SELECT_ID) {
            return;
        }

        var selectTool:MESelectTool = METool.GetTool(METool.SELECT_ID, this) as MESelectTool;
        selectTool.dragSelection(0, 1, this.timeControl.getHistory(this.mapView.id));
    }

    private function onMoveSelectionLeft(e:Event):void {
        if (this.mapView == null || this.selectedTool.id != METool.SELECT_ID) {
            return;
        }

        var selectTool:MESelectTool = METool.GetTool(METool.SELECT_ID, this) as MESelectTool;
        selectTool.dragSelection(-1, 0, this.timeControl.getHistory(this.mapView.id));
    }

    private function onMoveSelectionRight(e:Event):void {
        if (this.mapView == null || this.selectedTool.id != METool.SELECT_ID) {
            return;
        }

        var selectTool:MESelectTool = METool.GetTool(METool.SELECT_ID, this) as MESelectTool;
        selectTool.dragSelection(1, 0, this.timeControl.getHistory(this.mapView.id));
    }

    private function onBrushChanged(e:Event):void {
        var tilePos:IntPoint = this.getMouseTilePosition();
        if (tilePos == null) {
            return;
        }

        if (this.selectedTool.id == METool.ERASER_ID) {
            this.mapView.drawBrushOutline(tilePos.x_, tilePos.y_, this.userBrush);
        } else {
            this.mapView.drawBrushTiles(tilePos.x_, tilePos.y_, this.userBrush);
        }

        this.brushOptions.updateBrush(this.userBrush);
        this.selectedTool.brushChanged(tilePos, this.timeControl.getHistory(this.mapView.id));
    }

    private function onDeleteSelection(e:Event):void {
        if (this.mapView.selection == MapView.EMPTY_SELECTION)
            return;

        MEEraserTool.eraseSelection(this, this.mapView.selection, this.timeControl.getHistory(this.mapView.id));
    }

    private function onToggleDebug(e:Event):void {
        if (this.debugView == null) {
            this.debugView = new DebugView();
            addChild(this.debugView);
        } else {
            this.debugView.show(!this.debugView.visible);
        }

        this.updatePositions();
    }

    private function onMapDimensionsClick(e:Event):void {
        if (this.mapView == null){
            return;
        }

        if (this.mapDimensionsWindow == null) {
            this.mapDimensionsWindow = new MapDimensionsWindow();
            this.mapDimensionsWindow.x = (StageWidth - this.mapDimensionsWindow.width) / 2;
            this.mapDimensionsWindow.y = (StageHeight - this.mapDimensionsWindow.height) / 2;
            this.mapDimensionsWindow.addEventListener(MEEvent.MAP_DIMENSIONS_CHANGE, this.onMapDimensionsChange);
            addChild(this.mapDimensionsWindow);
        } else {
            this.mapDimensionsWindow.visible = true;
        }
        this.updatePositions();
    }

    private function onMapDimensionsChange(e:Event):void { // Changing map size basically creates a new map and pastes the previous map's data onto it
        var width:int = this.mapDimensionsWindow.mapWidth;
        var height:int = this.mapDimensionsWindow.mapHeight;

        this.mapData.changeMapDimensions(this.mapView, width, height);
        this.mapInfoPanel.visible = true;
        this.mapInfoPanel.setInfo(width, height);

        this.updatePositions();
    }

    private function updateBrushOptionsPosition(e:Event):void {
        this.brushOptions.x = this.drawElementsList.x - this.brushOptions.width - 8;
        this.brushOptions.y = this.testMapButton.y;
    }

    private function onTileHotkey(e:TileHotkeyEvent):void {
        var select:MapDrawElement = null;
        for each (var obj:DisplayObject in stage.getObjectsUnderPoint(new Point(stage.mouseX, stage.mouseY))) {
            if (obj is MapDrawElement) {
                select = obj as MapDrawElement;
            }
            if (obj.parent != null && obj.parent is MapDrawElement) {
                select = obj.parent as MapDrawElement;
            }
        }

        // Add hotkey for element
        if (select != null) {
            tileHotkeys.setHotkey(e.number, select);
            this.updatePositions();
            return;
        }

        // Switch to hotkey
        var hotkeyElement:MapDrawElement = tileHotkeys.getElement(e.number);
        if (hotkeyElement == null)
            return;

        switch (hotkeyElement.drawType) {
            case MEDrawType.GROUND:
                this.userBrush.setGroundType(hotkeyElement.elementType);
                break;
            case MEDrawType.OBJECTS:
                this.userBrush.setObjectType(hotkeyElement.elementType);
                break;
            case MEDrawType.REGIONS:
                this.userBrush.setRegionType(hotkeyElement.elementType);
                break;
        }

        this.drawTypeSwitch.select(hotkeyElement.drawType);
        this.tileHotkeys.switchTo(e.number);
    }
}
}
