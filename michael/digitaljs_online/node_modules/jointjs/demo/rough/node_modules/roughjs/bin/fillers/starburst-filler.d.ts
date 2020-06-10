import { PatternFiller, RenderHelper } from './filler-interface';
import { ResolvedOptions, OpSet } from '../core';
import { Point } from '../geometry';
export declare class StarburstFiller implements PatternFiller {
    private helper;
    constructor(helper: RenderHelper);
    fillPolygon(points: Point[], o: ResolvedOptions): OpSet;
    fillEllipse(cx: number, cy: number, width: number, height: number, o: ResolvedOptions): OpSet;
    fillArc(x: number, y: number, width: number, height: number, start: number, stop: number, o: ResolvedOptions): OpSet | null;
    private fillArcSegment;
    private drawLines;
    private createLinesFromCenter;
    private removeDuplocatePoints;
}
