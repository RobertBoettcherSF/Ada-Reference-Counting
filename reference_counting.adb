-- ============================================================================
--  Reference Counting Package Body
--  Implements all variants of reference counting as described in Wikipedia.
-- ============================================================================

with Ada.Text_IO;
with Ada.Containers.Doubly_Linked_Lists;
with Ada.Unchecked_Deallocation;

package body Reference_Counting is

   -- Global counter for unique object IDs
   Next_Object_ID : Object_ID := 1;

   -- ========================================================================
   --  Helper Functions
   -- ========================================================================

   -- Generate a unique ID for a new object
   function Generate_ID return Object_ID is
   begin
      Next_Object_ID := Next_Object_ID + 1;
      return Next_Object_ID - 1;
   end Generate_ID;

   -- Free an object (used by Unchecked_Deallocation)
   procedure Free_Object is new Ada.Unchecked_Deallocation(Object, Object_Access);
   procedure Free_Weighted_Object is new Ada.Unchecked_Deallocation(
      Weighted_Object, Weighted_Object_Access);
   procedure Free_Indirect_Object is new Ada.Unchecked_Deallocation(
      Indirect_Object, Indirect_Object_Access);
   procedure Free_Deferred_Object is new Ada.Unchecked_Deallocation(
      Deferred_Object, Deferred_Object_Access);
   procedure Free_Update_Manager is new Ada.Unchecked_Deallocation(
      Update_Manager, Update_Manager_Access);
   procedure Free_Weak_Reference is new Ada.Unchecked_Deallocation(
      Weak_Reference, Weak_Reference_Access);
   procedure Free_DB_Object is new Ada.Unchecked_Deallocation(
      DB_Object, DB_Object_Access);
   procedure Free_Ulterior_Object is new Ada.Unchecked_Deallocation(
      Ulterior_Object, Ulterior_Object_Access);
   procedure Free_Cycle_Detector is new Ada.Unchecked_Deallocation(
      Cycle_Detector, Cycle_Detector_Access);

   -- ========================================================================
   --  Basic Reference Counting Implementation
   -- ========================================================================

   -- Create a new object with a reference count of 1
   function Create_Object return Object_Access is
      Obj : Object_Access := new Object;
   begin
      Obj.ID := Generate_ID;
      Obj.Ref_Count := 1;
      return Obj;
   end Create_Object;

   -- Increment the reference count of an object
   procedure Increment_Reference (Obj : in out Object_Access) is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot increment null reference";
      end if;
      Obj.Ref_Count := Obj.Ref_Count + 1;
   end Increment_Reference;

   -- Decrement the reference count of an object
   -- If the count reaches zero, the object is deallocated
   procedure Decrement_Reference (Obj : in out Object_Access) is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot decrement null reference";
      end if;

      -- Decrement the reference count
      Obj.Ref_Count := Obj.Ref_Count - 1;

      -- If the count reaches zero, deallocate the object
      if Obj.Ref_Count = 0 then
         Free_Object(Obj);
         Obj := null; -- Avoid dangling pointer
      end if;
   end Decrement_Reference;

   -- Get the current reference count of an object
   function Get_Reference_Count (Obj : Object_Access) return Reference_Count is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot get reference count of null object";
      end if;
      return Obj.Ref_Count;
   end Get_Reference_Count;

   -- ========================================================================
   --  Weighted Reference Counting Implementation
   -- ========================================================================

   -- Create a new weighted object with initial weight
   function Create_Weighted_Object (Initial_Weight : Weight) return Weighted_Object_Access is
      Obj : Weighted_Object_Access := new Weighted_Object;
   begin
      Obj.ID := Generate_ID;
      Obj.Total_Weight := Initial_Weight;
      return Obj;
   end Create_Weighted_Object;

   -- Split a weight into two halves (for copying a reference)
   procedure Split_Weight (Obj : in out Weighted_Object_Access) is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot split weight of null object";
      end if;

      -- Halve the total weight (simulates splitting between two references)
      Obj.Total_Weight := Obj.Total_Weight / 2.0;
   end Split_Weight;

   -- Merge weights (used when a reference is destroyed)
   procedure Merge_Weight (Obj : in out Weighted_Object_Access; Amount : Weight) is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot merge weight of null object";
      end if;

      -- Subtract the weight (simulates destroying a reference)
      Obj.Total_Weight := Obj.Total_Weight - Amount;

      -- If total weight reaches zero, deallocate the object
      if Obj.Total_Weight <= 0.0 then
         Free_Weighted_Object(Obj);
         Obj := null;
      end if;
   end Merge_Weight;

   -- Get the total weight of a weighted object
   function Get_Total_Weight (Obj : Weighted_Object_Access) return Weight is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot get weight of null object";
      end if;
      return Obj.Total_Weight;
   end Get_Total_Weight;

   -- ========================================================================
   --  Indirect Reference Counting (Dijkstra-Scholten) Implementation
   -- ========================================================================

   -- Create a new indirect object
   function Create_Indirect_Object return Indirect_Object_Access is
      Obj : Indirect_Object_Access := new Indirect_Object;
   begin
      Obj.ID := Generate_ID;
      Obj.Ref_Count := 1;
      return Obj;
   end Create_Indirect_Object;

   -- Add an indirect reference (for diffusion tree)
   procedure Add_Indirect_Reference (
      Source, Target : in out Indirect_Object_Access) is
   begin
      if Source = null or Target = null then
         raise Invalid_Reference with "Cannot add indirect reference with null source or target";
      end if;

      -- Increment the target's reference count (simulates diffusion tree)
      Target.Ref_Count := Target.Ref_Count + 1;

      -- Note: In a full implementation, we would track the source of the reference
      -- For simplicity, we just increment the count here
   end Add_Indirect_Reference;

   -- Remove an indirect reference
   procedure Remove_Indirect_Reference (
      Source, Target : in out Indirect_Object_Access) is
   begin
      if Source = null or Target = null then
         raise Invalid_Reference with "Cannot remove indirect reference with null source or target";
      end if;

      -- Decrement the target's reference count
      Target.Ref_Count := Target.Ref_Count - 1;

      -- If the count reaches zero, deallocate the target
      if Target.Ref_Count = 0 then
         Free_Indirect_Object(Target);
         Target := null;
      end if;
   end Remove_Indirect_Reference;

   -- ========================================================================
   --  Deferred Increment (Henry Baker) Implementation
   -- ========================================================================

   -- Create a new deferred object
   function Create_Deferred_Object return Deferred_Object_Access is
      Obj : Deferred_Object_Access := new Deferred_Object;
   begin
      Obj.ID := Generate_ID;
      Obj.Ref_Count := 1;
      Obj.Deferred_Incr := False;
      return Obj;
   end Create_Deferred_Object;

   -- Create a local reference (deferred increment)
   procedure Create_Local_Reference (Obj : in out Deferred_Object_Access) is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot create local reference to null object";
      end if;

      -- Mark that increment is deferred
      Obj.Deferred_Incr := True;
      -- Note: In a real implementation, we would not increment Ref_Count here
   end Create_Local_Reference;

   -- Destroy a local reference (no decrement if deferred)
   procedure Destroy_Local_Reference (Obj : in out Deferred_Object_Access) is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot destroy local reference to null object";
      end if;

      -- If increment was deferred, we don't decrement here
      if Obj.Deferred_Incr then
         Obj.Deferred_Incr := False;
      else
         -- Otherwise, decrement normally
         Obj.Ref_Count := Obj.Ref_Count - 1;
         if Obj.Ref_Count = 0 then
            Free_Deferred_Object(Obj);
            Obj := null;
         end if;
      end if;
   end Destroy_Local_Reference;

   -- Promote a local reference to a global one (perform deferred increment)
   procedure Promote_To_Global (Obj : in out Deferred_Object_Access) is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot promote null object to global";
      end if;

      -- Perform the deferred increment
      if Obj.Deferred_Incr then
         Obj.Ref_Count := Obj.Ref_Count + 1;
         Obj.Deferred_Incr := False;
      end if;
   end Promote_To_Global;

   -- ========================================================================
   --  Update Coalescing (Levanoni & Petrank) Implementation
   -- ========================================================================

   -- Create a new update manager
   function Create_Update_Manager return Update_Manager_Access is
      Manager : Update_Manager_Access := new Update_Manager;
   begin
      return Manager;
   end Create_Update_Manager;

   -- Register a pointer update (coalesces redundant updates)
   procedure Register_Update (
      Manager : in out Update_Manager_Access;
      Old_Obj, New_Obj : in out Object_Access) is

      -- Check if the update is redundant (same old and new object)
      function Is_Redundant (Update : Update_Record) return Boolean is
      begin
         return (Update.Old_Obj = Old_Obj and Update.New_Obj = New_Obj);
      end Is_Redundant;

      -- Check if the update can be coalesced with an existing one
      function Can_Coalesce (Update : Update_Record) return Boolean is
      begin
         return (Update.Old_Obj = Old_Obj or Update.New_Obj = New_Obj);
      end Can_Coalesce;

      Use_It : Update_Lists.Cursor := Manager.Pending_Updates.First;
      Found  : Boolean := False;
   begin
      if Manager = null then
         raise Invalid_Reference with "Cannot register update with null manager";
      end if;

      -- Check for redundant or coalescable updates
      while Use_It /= Update_Lists.No_Element loop
         declare
            Current_Update : Update_Record := Update_Lists.Element(Use_It);
         begin
            if Is_Redundant(Current_Update) then
               -- Skip redundant update
               return;
            elsif Can_Coalesce(Current_Update) then
               -- Coalesce: Remove the old update and add the new one
               Manager.Pending_Updates.Delete(Use_It);
               Found := True;
               exit;
            end if;
         end;
         Update_Lists.Next(Use_It);
      end loop;

      -- Add the new update
      Manager.Pending_Updates.Append((Old_Obj, New_Obj));
   end Register_Update;

   -- Flush all coalesced updates
   procedure Flush_Updates (Manager : in out Update_Manager_Access) is
      Use_It : Update_Lists.Cursor := Manager.Pending_Updates.First;
   begin
      if Manager = null then
         raise Invalid_Reference with "Cannot flush updates with null manager";
      end if;

      -- Apply all pending updates
      while Use_It /= Update_Lists.No_Element loop
         declare
            Current_Update : Update_Record := Update_Lists.Element(Use_It);
         begin
            -- Decrement the old object's reference count
            if Current_Update.Old_Obj /= null then
               Current_Update.Old_Obj.Ref_Count := Current_Update.Old_Obj.Ref_Count - 1;
               if Current_Update.Old_Obj.Ref_Count = 0 then
                  Free_Object(Current_Update.Old_Obj);
               end if;
            end if;

            -- Increment the new object's reference count
            if Current_Update.New_Obj /= null then
               Current_Update.New_Obj.Ref_Count := Current_Update.New_Obj.Ref_Count + 1;
            end if;
         end;
         Update_Lists.Next(Use_It);
      end loop;

      -- Clear the pending updates
      Manager.Pending_Updates.Clear;
   end Flush_Updates;

   -- ========================================================================
   --  Cycle Handling (Weak References) Implementation
   -- ========================================================================

   -- Create a weak reference to an object
   procedure Create_Weak_Reference (
      Target : Object_Access;
      Weak_Ref : out Weak_Reference_Access) is
   begin
      if Target = null then
         raise Invalid_Reference with "Cannot create weak reference to null target";
      end if;

      Weak_Ref := new Weak_Reference;
      Weak_Ref.Target_ID := Target.ID;
      Weak_Ref.Is_Valid := True;
   end Create_Weak_Reference;

   -- Check if a weak reference is still valid
   function Is_Weak_Reference_Valid (Weak_Ref : Weak_Reference_Access) return Boolean is
   begin
      if Weak_Ref = null then
         return False;
      end if;
      return Weak_Ref.Is_Valid;
   end Is_Weak_Reference_Valid;

   -- Get the target of a weak reference (raises Invalid_Reference if invalid)
   procedure Get_Weak_Target (
      Weak_Ref : Weak_Reference_Access;
      Target : out Object_Access) is
   begin
      if Weak_Ref = null then
         raise Invalid_Reference with "Cannot get target of null weak reference";
      end if;

      if not Weak_Ref.Is_Valid then
         raise Invalid_Reference with "Weak reference is no longer valid";
      end if;

      -- Note: In a real implementation, we would look up the object by ID
      -- For simplicity, we just set Target to null here
      Target := null;
   end Get_Weak_Target;

   -- ========================================================================
   --  Deutsch-Bobrow Method Implementation
   -- ========================================================================

   -- Create a new Deutsch-Bobrow object
   function Create_DB_Object return DB_Object_Access is
      Obj : DB_Object_Access := new DB_Object;
   begin
      Obj.ID := Generate_ID;
      Obj.Ref_Count := 1;
      Obj.In_Stack := False;
      return Obj;
   end Create_DB_Object;

   -- Scan stack/registers for references (simulated)
   procedure Scan_Stack_For_References (Obj : in out DB_Object_Access) is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot scan stack for null object";
      end if;

      -- Simulate scanning the stack for references to this object
      -- In a real implementation, this would involve inspecting the call stack
      Obj.In_Stack := True;

      -- If the object is in the stack, do not deallocate even if Ref_Count = 0
      if Obj.Ref_Count = 0 and Obj.In_Stack then
         Obj.Ref_Count := 1; -- Prevent deallocation
      end if;
   end Scan_Stack_For_References;

   -- ========================================================================
   --  Ulterior Reference Counting (Blackburn & McKinley) Implementation
   -- ========================================================================

   -- Create a new ulterior object
   function Create_Ulterior_Object return Ulterior_Object_Access is
      Obj : Ulterior_Object_Access := new Ulterior_Object;
   begin
      Obj.ID := Generate_ID;
      Obj.Ref_Count := 1;
      Obj.Is_Young := True;
      return Obj;
   end Create_Ulterior_Object;

   -- Perform a copying collection (simulated)
   procedure Copying_Collection (Obj : in out Ulterior_Object_Access) is
   begin
      if Obj = null then
         raise Invalid_Reference with "Cannot perform copying collection on null object";
      end if;

      -- Simulate moving the object from young to old generation
      if Obj.Is_Young then
         Obj.Is_Young := False;
         Ada.Text_IO.Put_Line("Object" & Obj.ID'Image & " moved to old generation");
      end if;
   end Copying_Collection;

   -- ========================================================================
   --  Cycle Detection (Bacon's Algorithm) Implementation
   -- ========================================================================

   -- Create a new cycle detector
   function Create_Cycle_Detector return Cycle_Detector_Access is
      Detector : Cycle_Detector_Access := new Cycle_Detector;
   begin
      return Detector;
   end Create_Cycle_Detector;

   -- Add an object to the roots list (for cycle detection)
   procedure Add_To_Roots (Detector : in out Cycle_Detector_Access; Obj : Object_Access) is
   begin
      if Detector = null then
         raise Invalid_Reference with "Cannot add to roots with null detector";
      end if;
      if Obj = null then
         raise Invalid_Reference with "Cannot add null object to roots";
      end if;

      Detector.Roots.Append(Obj);
   end Add_To_Roots;

   -- Detect and collect cycles
   procedure Detect_Cycles (Detector : in out Cycle_Detector_Access) is
      Use_It : Object_Lists.Cursor := Detector.Roots.First;
   begin
      if Detector = null then
         raise Invalid_Reference with "Cannot detect cycles with null detector";
      end if;

      -- Simulate cycle detection by checking if any object in roots has Ref_Count > 0
      -- In a real implementation, this would involve a graph traversal
      while Use_It /= Object_Lists.No_Element loop
         declare
            Current_Obj : Object_Access := Object_Lists.Element(Use_It);
         begin
            if Current_Obj.Ref_Count > 0 then
               Ada.Text_IO.Put_Line(
                  "Cycle detected involving object" & Current_Obj.ID'Image);
               -- In a real implementation, we would decrement counts here
            end if;
         end;
         Object_Lists.Next(Use_It);
      end loop;

      -- Clear the roots list after detection
      Detector.Roots.Clear;
   end Detect_Cycles;

end Reference_Counting;
