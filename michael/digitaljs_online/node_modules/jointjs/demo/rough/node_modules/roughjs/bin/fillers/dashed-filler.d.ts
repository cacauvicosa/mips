import { PatternFiller, RenderHelper } from './filler-interface';
import { ResolvedOptions, OpSet } from '../core';
import { Point } from '../geometry';
export declare class DashedFiller implements PatternFiller {
    private helper;
    constructor(helper: RenderHelper);
    fillPolygon(points: Point[], o: ResolvedOptions): OpSet;
    fillEllipse(cx: number, cy: number, width: number, height: number, o: ResolvedOptions): OpSet;
    fillArc(_x: number, _y: number, _width: number, _height: number, _start: number, _stop: number, _o: ResolvedOptions): OpSet | null;
    private dashedLine;
}
