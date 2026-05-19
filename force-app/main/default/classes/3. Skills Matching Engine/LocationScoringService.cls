public class LocationScoringService {

    public static Decimal calculate(
        String candidateLocation,
        String positionLocation,
        Boolean candidateRemote,
        Boolean positionRemote
    ) {

        // 1. Remote override (самый высокий приоритет)
        if(candidateRemote == true &&
           positionRemote == true) {
            return 100;
        }

        // 2. Same city match
        if(candidateLocation != null &&
           positionLocation != null &&
           candidateLocation.equalsIgnoreCase(positionLocation)) {
            return 100;
        }

        // 3. Adjacent region (упрощённая логика)
        if(candidateLocation != null &&
           positionLocation != null) {

            String c = candidateLocation.toLowerCase();
            String p = positionLocation.toLowerCase();

            // пример условной "смежности"
            if(c.contains(p) || p.contains(c)) {
                return 70;
            }
        }

        // 4. Default mismatch
        return 30;
    }
}