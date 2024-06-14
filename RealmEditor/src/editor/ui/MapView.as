package editor.ui {
import assets.ground.GroundLibrary;
import assets.objects.ObjectLibrary;
import assets.regions.RegionLibrary;

import editor.actions.MapAction;
import editor.MEBrush;
import editor.MEClipboard;
import editor.MEDrawType;
import editor.tools.METool;
import editor.actions.MapAction;
import editor.actions.MapAction;
import editor.MapData;
import editor.MapTileData;

import flash.display.Bitmap;

import flash.display.BitmapData;

import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.utils.Dictionary;

import util.IntPoint;

public class MapView extends Sprite {

    public var id:int; // Id of the map (based on load/create order)
    public var mapData:MapData;
    public var tileMap:TileMapView;
    public var mapOffset:IntPoint;
    public var zoomLevel:int = 100;
    public var gridEnabled:Boolean;
    private var gridTexture:BitmapData;
    private var grid:Bitmap;

    private var selectionSize:IntPoint;
    private var selectionRect:Shape;
    private var highlightRect:Shape;
    private var brushPencil:Bitmap; // Draws a transparent view of the tiles (ground/object/region) the user will be painting on the map
    private var brushDrawType:int;
    private var brushTextureType:int;

    public var lastDragPos:IntPoint;
    private var tilesMoved:Dictionary;

    public function MapView(id:int, mapData:MapData) {
        this.id = id;
        this.mapData = mapData;
        this.mapOffset = new IntPoint();

        this.grid = new Bitmap(null);
        this.grid.visible = false;
        addChild(this.grid);

        this.tileMap = new TileMapView();
        addChild(this.tileMap);

        this.highlightRect = new Shape();
        addChild(this.highlightRect);

        this.selectionSize = new IntPoint(0, 0);
        this.selectionRect = new Shape();
        addChild(this.selectionRect);

        this.brushPencil = new Bitmap();
        this.brushPencil.alpha = 0.9;
        addChild(this.brushPencil);
    }

    private function drawGrid():void {
        for (var i:int = 0; i <= this.mapData.mapWidth; i++) { // Vertical lines
            var x:Number = TileMapView.TILE_SIZE * i;
            this.gridTexture.fillRect(new Rectangle(x, 0, 1, this.gridTexture.height), 1593835520 | 0xFF0000);
        }
        for (i = 0; i <= this.mapData.mapHeight; i++) { // Horizontal lines
            var y:Number = TileMapView.TILE_SIZE * i;
            this.gridTexture.fillRect(new Rectangle(0, y, this.gridTexture.width, 1), 1593835520 | 0xFF0000);
        }

        this.grid.bitmapData = this.gridTexture;
    }

    public function onMapLoadBegin():void {
//        trace("GRAPHICS CLEARED");

        this.selectionSize.x_ = 0;
        this.selectionSize.y_ = 0;
        this.selectionRect.graphics.clear();
        this.highlightRect.graphics.clear();
        // Clear user and undo actions

        this.tileMap.graphics.clear();
        if (this.gridTexture) {
            this.gridTexture.dispose();
            this.gridTexture = null;
        }

        this.gridTexture = new BitmapData(TileMapView.TILE_SIZE * this.mapData.mapWidth, TileMapView.TILE_SIZE * this.mapData.mapHeight, true, 0);
    }

    public function onMapLoadEnd():void {
//        trace("MAP LOADED");

        this.tileMap.onMapLoadEnd();
        this.drawGrid();
    }

    public function toggleGrid():Boolean {
        if (this.grid == null) {
            return false;
        }
        var val:Boolean = this.grid.visible = !this.grid.visible;
        this.gridEnabled = val;
        return val;
    }

    public function clearTileSelection():void {
        this.selectionSize.x_ = 0;
        this.selectionSize.y_ = 0;
        this.selectionRect.graphics.clear();
        this.resetSelectionMovement();
    }

    private function resetSelectionMovement():void {
        this.lastDragPos = null;
        this.tilesMoved = null;
        // Don't reset revertMoveHistory, we need to be able to undo previous movements too ;)
    }

    public function selectSingleTile(mapX:int, mapY:int):void { // If user clicks on just one tile, clear selection and add tile to the new selection
        var tile:MapTileSprite = this.tileMap.getTileSprite(mapX, mapY);
        if (tile == null) {
            return;
        }

        var startX:int = mapX * TileMapView.TILE_SIZE;
        var startY:int = mapY * TileMapView.TILE_SIZE;

        if (this.selectionRect.x == startX && this.selectionRect.y == startY) {
            this.clearTileSelection();
            return;
        }

        this.drawTileSelection(mapX, mapY, mapX, mapY); // Redraw the tile selection rectangle
    }

    public function selectTileArea(mapStartX:int, mapStartY:int, mapEndX:int, mapEndY:int, movementCall:Boolean = false, userAction:Boolean = true, firstAction:Boolean = true, lastAction:Boolean = true):void { // Use this for selecting a rectangle area of tiles by holding left mouse button
        var beginX:int = mapStartX < mapEndX ? mapStartX : mapEndX;
        var beginY:int = mapStartY < mapEndY ? mapStartY : mapEndY;
        var endX:int = mapStartX < mapEndX ? mapEndX : mapStartX;
        var endY:int = mapStartY < mapEndY ? mapEndY : mapStartY;

        if (movementCall) {
             // Push to user history
        }
        else if (userAction) { // Clear tile movement if the user has selected a new tile area
            this.resetSelectionMovement();
        }

        this.drawTileSelection(beginX, beginY, endX, endY); // Redraw the tile selection rectangle
    }

    public function highlightTile(mapX:int, mapY:int):void { // Draws rectangle over hovered tile
        var g:Graphics = this.highlightRect.graphics;
        g.clear(); // Always clear the highlight first

        if (mapX < 0 || mapX > this.mapData.mapWidth || mapY < 0 || mapY > this.mapData.mapHeight) {
            return;
        }

        var x:int = mapX * TileMapView.TILE_SIZE;
        var y:int = mapY * TileMapView.TILE_SIZE;
        var width:int = TileMapView.TILE_SIZE;
        var height:int = TileMapView.TILE_SIZE;

        g.lineStyle(1, 0xFFFFFF, 0.5);
        g.drawRect(x, y, width, height);
        g.lineStyle();
    }

    public function hideBrushTiles():void {
        this.brushPencil.visible = false;
    }

    public function moveBrushTiles(mapX:int, mapY:int, brush:MEBrush):void {
        if (brush.drawType != this.brushDrawType) { // Re-draw if the draw type has changed
            this.drawBrushTiles(mapX, mapY, brush);
            return;
        }

        switch (brush.drawType) { // If draw type matces,re-draw if the texture we're drawing also has changed
            case MEDrawType.GROUND:
                if (brush.groundType != this.brushTextureType) {
                    this.drawBrushTiles(mapX, mapY, brush);
                    return;
                }
                break;
            case MEDrawType.OBJECTS:
                if (brush.objType != this.brushTextureType) {
                    this.drawBrushTiles(mapX, mapY, brush);
                    return;
                }
                break;
            case MEDrawType.REGIONS:
                if (brush.regType != this.brushTextureType) {
                    this.drawBrushTiles(mapX, mapY, brush);
                    return;
                }
                break;
        }

        this.brushPencil.x = (mapX - brush.size) * TileMapView.TILE_SIZE;
        this.brushPencil.y = (mapY - brush.size) * TileMapView.TILE_SIZE;
        this.brushPencil.visible = true;
    }

    public function drawBrushTiles(mapX:int, mapY:int, brush:MEBrush):void {
        var regColor:uint;
        var groundTexture:BitmapData;
        var objectTexture:BitmapData;

        this.brushDrawType = brush.drawType;
        switch (brush.drawType) {
            case MEDrawType.GROUND:
                groundTexture = GroundLibrary.getBitmapData(brush.groundType);
                this.brushTextureType = brush.groundType;
                break;
            case MEDrawType.OBJECTS:
                objectTexture = ObjectLibrary.getTextureFromType(brush.objType);
                this.brushTextureType = brush.objType;
                break;
            case MEDrawType.REGIONS:
                regColor = RegionLibrary.getColor(brush.regType);
                this.brushTextureType = brush.regType;
                break;
        }

        var diameter:int = (1 + (brush.size * 2)); // Times 2 because we have tiles on the front and on the back
        var center:int = diameter / 2;
        var bitmapSize:int = diameter * TileMapView.TILE_SIZE;
        var brushTexture:BitmapData = new BitmapData(bitmapSize, bitmapSize, true, 0);
        for (var yi:int = 0; yi <= diameter; yi++) { // The brush size represents the amount of tiles from the center we will render
            for (var xi:int = 0; xi <= diameter; xi++) {
                var dx:int = xi - center;
                var dy:int = yi - center;
                var distSq:int = dx * dx + dy * dy;
                if (distSq > brush.size * brush.size) {
                    continue;
                }

                if (groundTexture != null) {
                    brushTexture.copyPixels(groundTexture, new Rectangle(0, 0, groundTexture.width, groundTexture.height), new Point(xi * TileMapView.TILE_SIZE, yi * TileMapView.TILE_SIZE));
                } else if (objectTexture != null) {
                    brushTexture.copyPixels(objectTexture, new Rectangle(0, 0, objectTexture.width, objectTexture.height), new Point(xi * TileMapView.TILE_SIZE, yi * TileMapView.TILE_SIZE));
                } else { // Must mean we're rendering a region
                    brushTexture.fillRect(new Rectangle(xi * TileMapView.TILE_SIZE, yi * TileMapView.TILE_SIZE, 1, 1), 1593835520 | regColor);
                }
            }
        }

        if (this.brushPencil.bitmapData != null) { // Make sure to clear our previous textures before we start drawing again
            this.brushPencil.bitmapData.dispose();
            this.brushPencil.bitmapData = null;
        }

        this.brushPencil.bitmapData = brushTexture;
        this.brushPencil.x = (mapX - brush.size) * TileMapView.TILE_SIZE;
        this.brushPencil.y = (mapY - brush.size) * TileMapView.TILE_SIZE;
        this.brushPencil.visible = true;
    }

    private function drawTileSelection(mapStartX:int, mapStartY:int, mapEndX:int, mapEndY:int):void {
        var g:Graphics = this.selectionRect.graphics;
        g.clear(); // Always clear first

        var startX:int = mapStartX * TileMapView.TILE_SIZE;
        var startY:int = mapStartY * TileMapView.TILE_SIZE;
        var endX:int = mapEndX * TileMapView.TILE_SIZE;
        var endY:int = mapEndY * TileMapView.TILE_SIZE;

        var width:int = (endX + TileMapView.TILE_SIZE) - startX;
        var height:int = (endY + TileMapView.TILE_SIZE) - startY;

        g.lineStyle(0.5, 0xFFFFFF);
        g.drawRect(0, 0, width, height);
        g.lineStyle();

        this.selectionSize.x_ = width / TileMapView.TILE_SIZE;
        this.selectionSize.y_ = height / TileMapView.TILE_SIZE;
        this.selectionRect.x = startX;
        this.selectionRect.y = startY;
    }

    public function isInsideSelection(mapX:int, mapY:int, needsSelection:Boolean = false):Boolean {
        if (needsSelection && this.selectionRect.width == 0) {
            return false;
        }

        if (this.selectionRect.width != 0) {
            var spriteX:int = mapX * TileMapView.TILE_SIZE;
            var spriteY:int = mapY * TileMapView.TILE_SIZE;
            if (spriteX < this.selectionRect.x || spriteX >= this.selectionRect.x + this.selectionRect.width || // Check if tile is within selection limits
                    spriteY < this.selectionRect.y || spriteY >= this.selectionRect.y + this.selectionRect.height) {
                return false;
            }
        }
        return true;
    }

    public function editTileObjCfg(x:int, y:int, cfg:String):void {
        var tile:MapTileSprite = this.tileMap.getTileSprite(x, y);
        var data:MapTileData = tile.tileData;
        if (tile == null || data.objType == 0) {
            return;
        }

        var prevName:String = data.objCfg;
        tile.setObjectCfg(cfg);

        // Push to user history
    }

    public function useTool(toolId:int, mapX:int, mapY:int):void {
        var brush:MEBrush = Main.View.userBrush;
        if (brush == null) {
            return;
        }

        // Clear undo history since we just made new changes
        var prevTileData:MapTileData = this.tileMap.getTileData(mapX, mapY);
        switch (toolId) {
            case METool.ERASER_ID:
                if (prevTileData == null || !this.isInsideSelection(mapX, mapY)) {
                    return;
                }

                switch (brush.drawType) {
                    case MEDrawType.GROUND:
                        if (prevTileData.groundType == -1) {
                            return;
                        }

                        this.tileMap.clearGround(mapX, mapY);
                        break;
                    case MEDrawType.OBJECTS:
                        if (prevTileData.objType == 0) {
                            return;
                        }

                        this.tileMap.clearObject(mapX, mapY);
                        break;
                    case MEDrawType.REGIONS:
                        if (prevTileData.regType == 0) {
                            return;
                        }

                        this.tileMap.clearRegion(mapX, mapY);
                        break;
                }
                this.tileMap.drawTile(mapX, mapY); // Draw tile with new data
                break;
            case METool.PENCIL_ID:
                if (!this.isInsideSelection(mapX, mapY)) {
                    return;
                }

                switch (brush.drawType) {
                    case MEDrawType.GROUND:
                        var prevGround:int = prevTileData != null ? prevTileData.groundType : -1;
                        if (brush.groundType == -1 || prevGround == brush.groundType) { // Make sure to only save in history if something was actually changed
                            return;
                        }

                        this.tileMap.setTileGround(mapX, mapY, brush.groundType);
                        break;
                    case MEDrawType.OBJECTS:
                        var prevObj:int = prevTileData != null ? prevTileData.objType : -1;
                        if (brush.objType == -1 || prevObj == brush.objType) {
                            return;
                        }

                        this.tileMap.setTileObject(mapX, mapY, brush.objType);
                        break;
                    case MEDrawType.REGIONS:
                        var prevRegion:int = prevTileData != null ? prevTileData.regType : -1;
                        if (brush.regType == -1 || prevRegion == brush.regType) {
                            return;
                        }

                        this.tileMap.setTileRegion(mapX, mapY, brush.regType);
                        break;
                }
                this.tileMap.drawTile(mapX, mapY); // Draw tile with new data
                break;
            case METool.BUCKET_ID:
                if (!this.isInsideSelection(mapX, mapY, true)) { // Only use bucket with a selected area
                    return;
                }

                this.fillSelection(brush);
                break;
        }
    }

    public function copySelectionToClipboard(clipboard:MEClipboard):void {
        if (this.selectionRect.x == -1 && this.selectionRect.y == -1) {
            return;
        }

        var startX:int = this.selectionRect.x / TileMapView.TILE_SIZE;
        var startY:int = this.selectionRect.y / TileMapView.TILE_SIZE;
        var width:int = this.selectionSize.x_;
        var height:int = this.selectionSize.y_;

        clipboard.setSize(width, height);
        for (var mapY:int = startY; mapY < startY + height; mapY++) {
            for (var mapX:int = startX; mapX < startX + width; mapX++) {
                var tileData:MapTileData = this.tileMap.getTileData(mapX, mapY).clone(); // Save current tilemap data
                clipboard.addTile(tileData, mapX - startX, mapY - startY);
            }
        }
    }

    public function pasteFromClipboard(clipboard:MEClipboard, mapX:int, mapY:int):void {
        if (mapX < 0 || mapX > this.mapData.mapWidth || mapY < 0 || mapY > this.mapData.mapHeight || clipboard.width <= 0 || clipboard.height <= 0 ||
                mapX + clipboard.width > this.mapData.mapWidth || mapY + clipboard.height > this.mapData.mapHeight) {
            return;
        }

        // Clear undo history

        // Select pasted tiles
        this.clearTileSelection();
        this.drawTileSelection(mapX, mapY, mapX + clipboard.width - 1, mapY + clipboard.height - 1); // Make the new pasted tiles the new selection

        for (var tileY:int = mapY; tileY < mapY + clipboard.height; tileY++) { // Draw tile by tile from clipboard
            for (var tileX:int = mapX; tileX < mapX + clipboard.width; tileX++) {
                var tileData:MapTileData = clipboard.getTile(tileX - mapX, tileY - mapY);
                var prevData:MapTileData = this.tileMap.getTileData(tileX, tileY).clone();
                if (tileData == null || tileData == prevData) { // Skip empty tiles
                    continue;
                }

                this.tileMap.setTileData(tileX, tileY, tileData);
                this.tileMap.drawTile(tileX, tileY);
            }
        }
    }

    private function fillSelection(brush:MEBrush):void {
        var startX:int = this.selectionRect.x / TileMapView.TILE_SIZE;
        var startY:int = this.selectionRect.y / TileMapView.TILE_SIZE;
        var width:int = this.selectionSize.x_;
        var height:int = this.selectionSize.y_;

        for (var mapY:int = startY; mapY < startY + height; mapY++) {
            for (var mapX:int = startX; mapX < startX + width; mapX++) {
                var prevData:MapTileData = this.tileMap.getTileData(mapX, mapY);
                var actId:int;
                var prevValue:int;
                var newValue:int;
                switch (brush.drawType) {
                    case MEDrawType.GROUND:
                        actId = MapAction.FILL_GROUND;
                        prevValue = prevData == null ? -1 : prevData.groundType;
                        newValue = brush.groundType;
                        this.tileMap.setTileGround(mapX, mapY, brush.groundType);
                        break;
                    case MEDrawType.OBJECTS:
                        actId = MapAction.FILL_OBJECT;
                        prevValue = prevData == null ? 0 : prevData.objType;
                        newValue = brush.objType;
                        this.tileMap.setTileObject(mapX, mapY, brush.objType);
                        break;
                    case MEDrawType.REGIONS:
                        actId = MapAction.FILL_REGION;
                        prevValue = prevData == null ? 0 : prevData.regType;
                        newValue = brush.regType;
                        this.tileMap.setTileRegion(mapX, mapY, brush.regType);
                        break;
                }
                this.tileMap.drawTile(mapX, mapY);
            }
        }
    }

    // This is where we move the selected tiles
    // Basically works like this:
    // Step 1: Save tiles in the selected region
    // (once) Step 2: Clear selected tiles (blank space in the map)
    // Step 3: Paste the selected tiles wherever we want them to be
    // (start process again) Step 4: Save tiles in the selected region
    // Step 5: Revert the changes we made
    // Step 6: Repeat step 3
    public function dragSelection(diffX:int, diffY:int):void {
        var fromX:int = this.selectionRect.x / TileMapView.TILE_SIZE;
        var fromY:int = this.selectionRect.y / TileMapView.TILE_SIZE;
        var toX:int = fromX + diffX;
        var toY:int = fromY + diffY;

        var endX:int = toX + this.selectionSize.x_ - 1;
        var endY:int = toY + this.selectionSize.y_ - 1;
        if (diffX == 0 && diffY == 0) {
            return;
        }

        // Clear undo history

        if (this.tilesMoved == null) {
            this.saveSelectedTiles(fromX, fromY); // First we copy the selected tiles into a dictionary
            this.clearSelectedTiles(fromX, fromY); // Then we clear the space selected
        } else {
            this.saveSelectedTiles(fromX, fromY); // Save tiles again in case they were changed
        }

        this.undoTileMovement(); // Revert recent move changes

        this.drawSelectedTiles(fromX, fromY, toX, toY);

        this.selectTileArea(toX, toY, endX, endY, true, false, false, true);
    }

    public function moveSelectionTo(toPos:IntPoint):void {
        if (this.lastDragPos == null) {
            this.lastDragPos = toPos;
        }

        var diffX:int = toPos.x_ - this.lastDragPos.x_;
        var diffY:int = toPos.y_ - this.lastDragPos.y_;

        this.dragSelection(diffX, diffY);

        this.lastDragPos = toPos;
    }

    private function clearSelectedTiles(fromX:int, fromY:int):void {
        for (var ogY:int = fromY; ogY < fromY + this.selectionSize.y_; ogY++) { // Iterate through the selection
            for (var ogX:int = fromX; ogX < fromX + this.selectionSize.x_; ogX++) {
                this.tileMap.clearTile(ogX, ogY);
                this.tileMap.drawTile(ogX, ogY); // Draws the empty tile
            }
        }
    }

    private function saveSelectedTiles(fromX:int, fromY:int):void {
        this.tilesMoved = new Dictionary();
        for (var ogY:int = fromY; ogY < fromY + this.selectionSize.y_; ogY++) { // Iterate through the selection
            for (var ogX:int = fromX; ogX < fromX + this.selectionSize.x_; ogX++) {
                var idx:int = (ogX - fromX) + (ogY - fromY) * this.selectionSize.x_;
                var ogTile:MapTileData = this.tileMap.getTileData(ogX, ogY).clone();

                this.tilesMoved[idx] = ogTile; // Save the tile data
            }
        }
    }

    private function drawSelectedTiles(fromX:int, fromY:int, toX:int, toY:int):void {
        for (var mapY:int = toY; mapY < toY + this.selectionSize.y_; mapY++) { // Draw moved tiles where they're supposed to be
            for (var mapX:int = toX; mapX < toX + this.selectionSize.x_; mapX++) {
                var idx:int = (mapX - toX) + (mapY - toY) * this.selectionSize.x_;
                var tile:MapTileData = this.tilesMoved[idx];

                this.tileMap.setTileData(mapX, mapY, tile);
                this.tileMap.drawTile(mapX, mapY);
            }
        }
    }

    private function undoTileMovement():void {

    }
}
}
