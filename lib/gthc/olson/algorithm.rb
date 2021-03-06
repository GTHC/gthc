require "gthc/olson/helpers"
require "gthc/olson/weight"

module Algorithm

  include Helpers
  extend Weight

  # Central document for creating schedule.
  def schedule(people, scheduleGrid)
    scheduleLength = scheduleGrid[0].length

    # Remove all availability slots that are already filled in the schedule.
    slots, graveyard, people = removeFilledSlots(people, scheduleGrid)

    # Remove all availability slots that are already filled in the schedule.
    while slots.length > 0

      # Weight Reset - set all weights to 1.
      slots = Weight.weightReset(slots)

      # Weight Balance - prioritize people with fewer scheduled shifts.
      people, slots = Weight.weightBalance(people, slots)

      # Weight Contiguous - prioritize people to stay in the tent more time at once.
      slots, scheduleGrid = Weight.weightContiguous(slots, scheduleGrid)

      # Weight Tough Time - prioritize time slots with few people available.
      slots = Weight.weightToughTime(slots, scheduleLength)

      # Sort by Weights
      slots.sort! { |a, b|  b.weight <=> a.weight }
      # pp slots

      # Update people, spreadsheet, and remove slots.
      people, slots, graveyard, scheduleGrid = Weight.weightPick(people, slots, graveyard, scheduleGrid)

    end

    return processData(people, scheduleGrid)

  end


  # Remove all availability slots that are already filled in the schedule.
  def removeFilledSlots(people, scheduleGrid)

    # Reset Slots Array.
    slots = Array.new
    # Set up graveyard (Rows that are completely scheduled will go here).
    graveyard = Array.new(scheduleGrid[0].length, 0)
    # Set up counterArray (Going to count how scheduled a row is).
    counterArray = Array.new(scheduleGrid[0].length, 0)

    # Count number of scheduled tenters during a specific time.
    scheduleGrid.each do | currentPerson |
      counter = 0
      while counter < currentPerson.length
        if currentPerson[counter].status == "Scheduled"
          counterArray[counter] = counterArray[counter] + 1
        end
        counter = counter + 1
      end
    end

    # Iterate through every slot.
    i = 0
    while i < scheduleGrid.length

      currentPerson = scheduleGrid[i]
      counter = 0

      while counter < scheduleGrid[i].length

        # Determine how many people are needed.
        isNight = currentPerson[counter].isNight
        phase = currentPerson[counter].phase
        peopleNeeded = Helpers.calculatePeopleNeeded(isNight, phase)
        numPeople = counterArray[counter]

        addToSlot = currentPerson[counter].status == "Available" || currentPerson[counter].status == "Somewhat"
        # Only add in slot if necessary.
        if numPeople < peopleNeeded && addToSlot
          slots.push(currentPerson[counter])
        end

        # Update graveyard
        if numPeople >= peopleNeeded
          graveyard[counter] = 1
        end

        # Update person freedom
        # if numPeople >= peopleNeeded  && currentPerson[counter].status == "Available"
        #   if isNight
        #     people[i].nightFree -= 1
        #   else
        #     people[i].dayFree -= 1
        #   end
        # end

        counter = counter + 1

      end

      i = i + 1

    end

    return slots, graveyard, people

  end

  def processData(people, scheduleGrid)
    # compress data from 2d grid with a single-deminsion of
    # all of the scheduled slots
    combinedGrid = []

    # iterating through every unique slot, and
    # checking for any people that are scheduled on that slot as well
    for slotIndex in 0...scheduleGrid[0].length
      slotData = scheduleGrid[0][slotIndex].to_hash
      slot = {
        "startDate": slotData["startDate"],
        "endDate": slotData["endDate"],
        "isNight": slotData["isNight"],
        "phase": slotData["phase"],
      }
      slot[:ids] = Array.new

      # checking every person at that slot for status
      for personIndex in 0...people.length
        person = people[personIndex]
        if scheduleGrid[personIndex][slotIndex].status == "Scheduled"
          slot[:ids].push(person.id)
        end
      end

      combinedGrid.push(slot)
    end

    # prints amount of people needed in a slot based on time and phase
    combinedGrid.each do | slot |
      peopleNeeded = Helpers.calculatePeopleNeeded slot[:isNight], slot[:phase]
      peopleLeft = peopleNeeded - slot[:ids].length
      slot[:peopleLeft] = peopleLeft
    end

    return combinedGrid, simplifyGrid(combinedGrid)
  end

  def simplifyGrid(combinedGrid)
    simplifiedGrid = []
    currentSlot = {}
    building = false
    combinedGrid.each_with_index do |slot, index|
      if building
        #if a slot has already started building
        if isConnectedSlot(currentSlot, slot)
          currentSlot[:endDate] = slot[:endDate]
          #if any of the slots are night, all are marked as night
          currentSlot[:isNight] = true if slot[:isNight]
        else
          simplifiedGrid.push currentSlot
          currentSlot = slot
        end
      else
        # if are starting a new slot
        currentSlot = slot
        building = true
      end
      simplifiedGrid.push currentSlot if index == combinedGrid.length - 1
    end
    simplifiedGrid
  end

  def isConnectedSlot(slot1, slot2)
    slot1[:ids] == slot2[:ids] and slot1[:phase] == slot2[:phase]
  end

end
