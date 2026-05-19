public class SalaryScoringService {

    public static Decimal calculate(
        Decimal candidateSalary,
        Decimal minSalary,
        Decimal maxSalary
    ) {

        if(candidateSalary == null ||
           minSalary == null ||
           maxSalary == null) {
            return 100;
        }

        
        if(candidateSalary >= minSalary &&
           candidateSalary <= maxSalary) {
            return 100;
        }

        
        if(candidateSalary < minSalary) {
            return 100;
        }

        
        Decimal ratio = candidateSalary / maxSalary;

        if(ratio <= 1.1) return 90;
        if(ratio <= 1.2) return 70;
        if(ratio <= 1.3) return 50;

        return 0;
    }
}