const ages: Record<number, (number | null)[]> = {
  0: [14, 18, null, 25, 35, 45, 55, 70],
  1: [30, 50, null, 80, 125, 175, 220, 260],
  2: [20, 25, null, 40, 60, 80, 100, 115],
  3: [100, 300, null, 500, 1000, 2000, 3000, 4500],
  4: [14, 20, null, 30, 45, 65, 85, 105],
  5: [20, 60, null, 130, 250, 375, 500, 600],
};
const ageLabels = ['veryYoung', 'young', 'adult', 'adult', 'middleAged', 'elderly', 'old', 'veryOld'];
export function ageDescription(race: number, age: number): string | undefined {
  if (!Number.isFinite(age) || !ages[race]) {
    return undefined;
  }
  const next = ages[race].findIndex((threshold) => threshold !== null && age < threshold);
  const index = next === -1 ? 8 : Math.max(1, next);
  return `characterCreation.age.${ageLabels[index - 1]}`;
}

// Height is relative to the selected race, rather than a human height standard.
export function heightDescription(height: number, min: number, max: number): string | undefined {
  if (!Number.isFinite(height) || max <= min) {
    return undefined;
  }
  const fraction = (height - min) / (max - min);
  const name =
    fraction < 0.2
      ? 'veryShort'
      : fraction < 0.4
        ? 'short'
        : fraction <= 0.6
          ? 'average'
          : fraction <= 0.8
            ? 'tall'
            : 'veryTall';
  return `characterCreation.height.${name}`;
}

export function buildDescription(heightInches: number, weightGrams: number, strength: number): string | undefined {
  if (![heightInches, weightGrams, strength].every(Number.isFinite) || heightInches <= 0 || weightGrams <= 0) {
    return undefined;
  }
  const meters = (heightInches * 2.54) / 100;
  const bmi = weightGrams / 1000 / (meters * meters);
  const index = Math.max(1, Math.min(7, Math.ceil((bmi - 16) / 3) + 1)) - 1;
  const names =
    strength < 7
      ? ['skinny', 'veryPetite', 'petite', 'average', 'chubby', 'plump', 'fat']
      : strength < 14
        ? ['lank', 'thin', 'slim', 'average', 'chubby', 'plump', 'fat']
        : ['wiry', 'veryWiry', 'average', 'athletic', 'muscular', 'robust', 'sturdy'];
  return `characterCreation.build.${names[index]}`;
}
