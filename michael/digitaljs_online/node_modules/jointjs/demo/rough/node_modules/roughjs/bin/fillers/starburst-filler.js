import { linerIntersection, centroid } from '../geometry';
export class StarburstFiller {
    constructor(helper) {
        this.helper = helper;
    }
    fillPolygon(points, o) {
        const xMinMax = [Number.MAX_SAFE_INTEGER, Number.MIN_SAFE_INTEGER];
        const yMinMax = [Number.MAX_SAFE_INTEGER, Number.MIN_SAFE_INTEGER];
        points.forEach((p) => {
            xMinMax[0] = Math.min(xMinMax[0], p[0]);
            xMinMax[1] = Math.max(xMinMax[1], p[0]);
            yMinMax[0] = Math.min(yMinMax[0], p[1]);
            yMinMax[1] = Math.max(yMinMax[1], p[1]);
        });
        const center = centroid(points);
        const radius = Math.max(Math.sqrt(Math.pow(center[0] - xMinMax[0], 2) + Math.pow(center[1] - yMinMax[0], 2)), Math.sqrt(Math.pow(center[0] - xMinMax[1], 2) + Math.pow(center[1] - yMinMax[1], 2)));
        const gap = o.hachureGap > 0 ? o.hachureGap : o.strokeWidth * 4;
        // polygon lines
        const lines = [];
        if (points.length > 2) {
            for (let i = 0; i < points.length; i++) {
                if (i === (points.length - 1)) {
                    lines.push([points[i], points[0]]);
                }
                else {
                    lines.push([points[i], points[i + 1]]);
                }
            }
        }
        // compute intersecting points
        let intersections = [];
        const count = Math.max(1, Math.PI * radius / gap);
        for (let i = 0; i < count; i++) {
            const angle = i * Math.PI / count;
            const cl = [center, [center[0] + radius * Math.cos(angle), center[1] + radius * Math.sin(angle)]];
            lines.forEach((l) => {
                const intersection = linerIntersection(l, cl);
                if (intersection && intersection[0] >= xMinMax[0] && intersection[0] <= xMinMax[1] && intersection[1] >= yMinMax[0] && intersection[1] <= yMinMax[1]) {
                    intersections.push(intersection);
                }
            });
        }
        intersections = this.removeDuplocatePoints(intersections);
        // draw lines
        const linesToDraw = this.createLinesFromCenter(center, intersections);
        const ops = this.drawLines(linesToDraw, o);
        return { type: 'fillSketch', ops };
    }
    fillEllipse(cx, cy, width, height, o) {
        return this.fillArcSegment(cx, cy, width, height, 0, Math.PI * 2, o);
    }
    fillArc(x, y, width, height, start, stop, o) {
        return this.fillArcSegment(x, y, width, height, start, stop, o);
    }
    fillArcSegment(cx, cy, width, height, start, stop, o) {
        const center = [cx, cy];
        const a = width / 2;
        const b = height / 2;
        const radius = Math.max(width / 2, height / 2);
        let gap = o.hachureGap;
        if (gap < 0) {
            gap = o.strokeWidth * 4;
        }
        const count = Math.max(1, Math.abs(stop - start) * radius / gap);
        let intersections = [];
        for (let i = 0; i < count; i++) {
            const angle = i * ((stop - start) / count) + start;
            const x0 = radius * Math.cos(angle);
            const y0 = radius * Math.sin(angle);
            const d = Math.sqrt((a * a * y0 * y0) + (b * b * x0 * x0));
            const xp = (a * b * x0) / d;
            const yp = (a * b * y0) / d;
            intersections.push([center[0] + xp, center[1] + yp]);
        }
        intersections = this.removeDuplocatePoints(intersections);
        // draw lines
        const linesToDraw = this.createLinesFromCenter(center, intersections);
        const ops = this.drawLines(linesToDraw, o);
        return { type: 'fillSketch', ops };
    }
    drawLines(lines, o) {
        let ops = [];
        lines.forEach((line) => {
            const pa = line[0];
            const pb = line[1];
            ops = ops.concat(this.helper.doubleLineOps(pa[0], pa[1], pb[0], pb[1], o));
        });
        return ops;
    }
    createLinesFromCenter(center, points) {
        return points.map((p) => [center, p]);
    }
    removeDuplocatePoints(points) {
        const keys = new Set();
        return points.filter((p) => {
            const key = p.join(',');
            if (keys.has(key)) {
                return false;
            }
            keys.add(key);
            return true;
        });
    }
}
