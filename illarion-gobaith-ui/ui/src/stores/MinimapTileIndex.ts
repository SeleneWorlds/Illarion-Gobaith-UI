/** Numeric row index avoids string construction and lookups for every minimap pixel. */
export class MinimapTileIndex {
  private readonly layers = new Map<number, Map<number, Map<number, number>>>();

  set(x: number, y: number, z: number, colorIndex: number): void {
    let rows = this.layers.get(z);
    if (!rows) { rows = new Map(); this.layers.set(z, rows); }
    let row = rows.get(y);
    if (!row) { row = new Map(); rows.set(y, row); }
    row.set(x, colorIndex);
  }

  *inRegion(x: number, y: number, z: number, width: number, height: number) {
    const rows = this.layers.get(z);
    if (!rows) {return;}
    for (let tileY = y; tileY < y + height; tileY += 1) {
      const row = rows.get(tileY);
      if (!row) {continue;}
      for (const [tileX, colorIndex] of row) {
        if (tileX >= x && tileX < x + width) {yield { x: tileX, y: tileY, colorIndex };}
      }
    }
  }
}
