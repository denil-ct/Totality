//
//  ContentView.swift
//  Totality
//
//  Created by Denil C T on 6/7/22.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    let store = HKHealthStore()
    @State var isReady = false
    @State var activeEnergy = 0.0
    @State var restingEnergy = 0.0
    @State var stepCount = 0.0
    @State var isLoadingHidden = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.22, green: 0.00, blue: 0.21),
                Color(red: 0.05, green: 0.73, blue: 0.73)
            ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                if isReady {
                    VStack(spacing: 20) {
                        Text("Previous Month Stats")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
                        VStack(spacing: 10) {
                            Text("Total Steps: \(Int(stepCount))")
                            Text("Total Active Energy: \(activeEnergy, specifier: "%.2f")")
                            Text("Total Resting Energy: \(restingEnergy, specifier: "%.2f")")
                            Text("Total Energy: \(activeEnergy + restingEnergy, specifier: "%.2f")")
                        }
                        .foregroundColor(.primary)
                        .foregroundStyle(.secondary)
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        VStack(spacing: 10) {
                            let numberOfDays = Double(getNumberOfDaysInPrevMonth())
                            Text("Average Energy: \((activeEnergy + restingEnergy)/numberOfDays, specifier: "%.2f")")
                            Text("Average Steps: \(stepCount/numberOfDays, specifier: "%.2f")")
                        }
                        .foregroundColor(.primary)
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        HStack {
                            Spacer()
                            Text("All energy values are in calories")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                } else {
                    Text("Please authorize the application")
                }
            }
            .hidden(!isLoadingHidden)
            ProgressView()
                .scaleEffect(3, anchor: .center)
                .padding(50)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius:16.0))
                .hidden(isLoadingHidden)
        }
        .task {
            if !HKHealthStore.isHealthDataAvailable() {
                return
            }
            
            guard await requestPermission() == true else {
                isLoadingHidden = true
                return
            }
            
            isReady = true
            activeEnergy = await readHealthData(for: .activeEnergyBurned)
            restingEnergy = await readHealthData(for: .basalEnergyBurned)
            stepCount = await readHealthData(for: .stepCount)
            isLoadingHidden = true
        }
    }
    
    private func requestPermission () async -> Bool {
        let activeEnergy = HKQuantityType(.activeEnergyBurned)
        let restingEnergy = HKQuantityType(.basalEnergyBurned)
        let steps = HKQuantityType(.stepCount)
        let read: Set = [
            activeEnergy,
            restingEnergy,
            steps
        ]
        
        let res: ()? = try? await store.requestAuthorization(toShare: [], read: read)
        guard res != nil else {
            return false
        }
        
        return true
    }
    
    private func readHealthData(for type: HKQuantityTypeIdentifier) async -> Double {
        let currentDate = Date()
        let energyPredicate = HKQuery.predicateForSamples(withStart: currentDate.getLastMonthStart(), end: currentDate.getLastMonthEnd(), options: .strictEndDate)
        let sampleType = HKQuantityType.init(type)
        
        let samples = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics, Error>) in
            store.execute(HKStatisticsQuery(quantityType: sampleType, quantitySamplePredicate: energyPredicate, options: .cumulativeSum) { query, samples, error in
                if let hasError = error {
                    continuation.resume(throwing: hasError)
                    return
                }
                
                guard let samples = samples else {
                    fatalError("*** Invalid State: This can only fail if there was an error. ***")
                }
                
                continuation.resume(returning: samples)
            })
        }
        
        switch type {
        case .stepCount:
            return samples?.sumQuantity()?.doubleValue(for: .count()) ?? 0.0
        default:
            return samples?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
        }
    }
    
    private func getNumberOfDaysInPrevMonth() -> Int {
        let date = Date().getLastMonthStart()
        let calendar = Calendar.current
        if let date = date {
            let range = calendar.range(of: .day, in: .month, for: date)
            return range?.count ?? 1
        }
        return 1
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension Date {
    func getLastMonthStart() -> Date? {
        let components:NSDateComponents = Calendar.current.dateComponents([.year, .month], from: self) as NSDateComponents
        components.month -= 1
        return Calendar.current.date(from: components as DateComponents)!
    }
    
    func getLastMonthEnd() -> Date? {
        let components:NSDateComponents = Calendar.current.dateComponents([.year, .month], from: self) as NSDateComponents
        components.day = 1
        return Calendar.current.date(from: components as DateComponents)!
    }
}
        
extension View  {
    @ViewBuilder func hidden(_ shouldHide: Bool) -> some View {
        switch shouldHide {
        case true: self.hidden()
        case false: self
        }
    }
}
