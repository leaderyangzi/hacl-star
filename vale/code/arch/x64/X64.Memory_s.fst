module X64.Memory_s

module I = Interop
module HS = FStar.HyperStack
module B = LowStar.Buffer
module M = LowStar.Modifies
open LowStar.ModifiesPat
module BV = LowStar.BufferView
module S = X64.Bytes_Semantics_s
module H = FStar.Heap

friend SecretByte

#reset-options "--initial_fuel 2 --max_fuel 2 --initial_ifuel 1 --max_ifuel 1"

let b8 = B.buffer UInt8.t

let heap = H.heap
noeq type mem' = {
  addrs : I.addr_map;
  ptrs : list b8;
  hs : HS.mem;
  }

type mem = (m:mem'{I.list_disjoint_or_eq #UInt8.t m.ptrs /\
  I.list_live m.hs m.ptrs})

let op_String_Access = Map.sel
let op_String_Assignment = Map.upd

let coerce (#a:Type0) (b:Type0{a == b}) (x:a) : b = x

let tuint8 = UInt8.t
let tuint16 = UInt16.t
let tuint32 = UInt32.t
let tuint64 = UInt64.t

let m_of_typ (t:typ) : Type0 =
  match t with
  | TBase TUInt8 -> tuint8
  | TBase TUInt16 -> tuint16
  | TBase TUInt32 -> tuint32
  | TBase TUInt64 -> tuint64
  | TBase TUInt128 -> quad32

let v_of_typ (t:typ) (v:type_of_typ t) :  (m_of_typ t) =
  match t with
  | TBase TUInt8 -> coerce ((m_of_typ t)) (UInt8.uint_to_t v)
  | TBase TUInt16 -> coerce ((m_of_typ t)) (UInt16.uint_to_t v)
  | TBase TUInt32 -> coerce ((m_of_typ t)) (UInt32.uint_to_t v)
  | TBase TUInt64 -> coerce ((m_of_typ t)) (UInt64.uint_to_t v)
  | TBase TUInt128 -> v

let v_to_typ (t:typ) (v:(m_of_typ t)) : type_of_typ t =
  match t with
  | TBase TUInt8 -> UInt8.v (coerce UInt8.t v)
  | TBase TUInt16 -> UInt16.v (coerce UInt16.t v)
  | TBase TUInt32 -> UInt32.v (coerce UInt32.t v)
  | TBase TUInt64 -> UInt64.v (coerce UInt64.t v)
  | TBase TUInt128 -> v

let lemma_v_to_of_typ (t:typ) (v:type_of_typ t) : Lemma
  (ensures v_to_typ t (v_of_typ t v) == v)
  [SMTPat (v_to_typ t (v_of_typ t v))]
  =
  match t with
  | TBase TUInt8 -> assert (UInt8.v (UInt8.uint_to_t v) == v)
  | TBase TUInt16 -> assert (UInt16.v (UInt16.uint_to_t v) == v)
  | TBase TUInt32 -> assert (UInt32.v (UInt32.uint_to_t v) == v)
  | TBase TUInt64 -> assert (UInt64.v (UInt64.uint_to_t v) == v)
  | TBase TUInt128 -> ()

let view_n = function
  | TBase TUInt8 -> 1
  | TBase TUInt16 -> 2
  | TBase TUInt32 -> 4
  | TBase TUInt64 -> 8
  | TBase TUInt128 -> 16

val uint8_view: (v:BV.view UInt8.t UInt8.t{BV.View?.n v == view_n (TBase TUInt8)})
val uint16_view: (v:BV.view UInt8.t UInt16.t{BV.View?.n v == view_n (TBase TUInt16)})
val uint32_view: (v:BV.view UInt8.t UInt32.t{BV.View?.n v == view_n (TBase TUInt32)})
val uint64_view: (v:BV.view UInt8.t UInt64.t{BV.View?.n v == view_n (TBase TUInt64)})
val uint128_view: (v:BV.view UInt8.t quad32{BV.View?.n v == view_n (TBase TUInt128)})

let uint8_view = Views.view8
let uint16_view = Views.view16
let uint32_view = Views.view32
let uint64_view = Views.view64
let uint128_view = Views.view128

val uint_view (t:typ) : (v:BV.view UInt8.t (m_of_typ t){BV.View?.n v == view_n t})

let uint_view = function
  | TBase TUInt8 -> uint8_view
  | TBase TUInt16 -> uint16_view
  | TBase TUInt32 -> uint32_view
  | TBase TUInt64 -> uint64_view
  | TBase TUInt128 -> uint128_view

let buffer t = (b:b8{B.length b % view_n t == 0})

let buffer_as_seq #t h b =
  let s = BV.as_seq h.hs (BV.mk_buffer_view b (uint_view t)) in
  let len = Seq.length s in
  let contents (i:nat{i < len}) : type_of_typ t = v_to_typ t (Seq.index s i) in
  Seq.init len contents

let buffer_readable #t h b = List.memP b h.ptrs
let buffer_length #t b = BV.length (BV.mk_buffer_view b (uint_view t))
let loc = M.loc
let loc_none = M.loc_none
let loc_union = M.loc_union
let loc_buffer #t b = M.loc_buffer b
let loc_disjoint = M.loc_disjoint
let loc_includes = M.loc_includes
let modifies s h h' =
  M.modifies s h.hs h'.hs /\ h.ptrs == h'.ptrs /\ h.addrs == h'.addrs

let valid_state s = s.state.S.mem == I.down_mem s.mem.hs s.mem.addrs s.mem.ptrs

let frame_valid s = ()

let same_domain h m = Set.equal (I.addrs_set h.ptrs h.addrs) (Map.domain m) /\ True  // TODO: /\ True is a temporary workaround for a temporary F*/OCaml extraction issue

let lemma_same_domains h m1 m2 = ()

let get_heap h = I.down_mem h.hs h.addrs h.ptrs

let same_heap s1 s2 = ()

let get_hs h m = 
  {h with hs = I.up_mem m h.addrs h.ptrs h.hs}

let get_hs_heap h = I.down_up_identity h.hs h.addrs h.ptrs

let get_heap_hs m h = I.up_down_identity h.hs h.addrs h.ptrs m

let buffer_addr #t b h =
  let addrs = h.addrs in
  addrs b

val index64_get_heap_val64 (h:mem)
                           (b:buffer64{List.memP b h.ptrs})
                           (heap:S.heap{I.correct_down h.hs h.addrs h.ptrs heap})
                           (i:nat{i < buffer_length b}) : Lemma
(Seq.index (buffer_as_seq h b) i == S.get_heap_val64 (buffer_addr b h + 8 `op_Multiply` i) heap)

#set-options "--z3rlimit 20"

let index64_heap_aux (s:Seq.lseq UInt8.t 8) (heap:S.heap) (ptr:int) : Lemma
  (requires forall (j:nat{j < 8}). UInt8.v (Seq.index s j) == heap.[ptr+j])
  (ensures UInt64.v (Views.get64 s) == S.get_heap_val64 ptr heap) =
  Opaque_s.reveal_opaque Views.get64_def;
  Opaque_s.reveal_opaque S.get_heap_val64_def;
  ()

let index_helper (x y:int) (heap:S.heap) : Lemma
  (requires x == y)
  (ensures heap.[x] == heap.[y]) = ()

let index_mul_helper (addr i n j:int) : Lemma
  (addr + (i `op_Multiply` n + j) == addr + n `op_Multiply` i + j) =
 ()

let index64_get_heap_val64 h b heap i =
  let open FStar.Mul in
  let vb = BV.mk_buffer_view b uint64_view in
  let ptr = buffer_addr b h + 8 * i in
  let s = B.as_seq h.hs b in
  let t = TBase TUInt64 in
  let addr = buffer_addr b h in
  BV.length_eq vb;
  BV.view_indexing vb i;
  BV.as_buffer_mk_buffer_view b uint64_view;
  BV.get_view_mk_buffer_view b uint64_view;
  BV.as_seq_sel h.hs vb i;
  BV.get_sel h.hs vb i;
  let s' = Seq.slice s (i*8) (i*8 + 8) in
  let aux (j:nat{j < 8}) : Lemma (UInt8.v (Seq.index s' j) == heap.[ptr+j]) =
    assert (UInt8.v (Seq.index s (i*8 + j)) == heap.[addr + (i*8+j)]);
    Seq.lemma_index_slice s (i*8) (i*8+8) j;
    assert (UInt8.v (Seq.index s' j) == heap.[addr+(i*8+j)]);
    index_mul_helper addr i 8 j;
    ()
  in Classical.forall_intro aux;
  index64_heap_aux s' heap ptr;
  ()

open Words_s

val index128_get_heap_val128 (h:mem)
                           (b:buffer128{List.memP b h.ptrs})
                           (heap:S.heap{I.correct_down h.hs h.addrs h.ptrs heap})
                           (i:nat{i < buffer_length b}) : Lemma
(let addr = buffer_addr b h in
 Seq.index (buffer_as_seq h b) i ==
  Mkfour
    (S.get_heap_val32 (addr + 16 `op_Multiply` i) heap)
    (S.get_heap_val32 (addr + 16 `op_Multiply` i+4) heap)
    (S.get_heap_val32 (addr + 16 `op_Multiply` i+8) heap)
    (S.get_heap_val32 (addr + 16 `op_Multiply` i +12) heap)
 )

#set-options "--z3rlimit 50"

let index128_get_heap_val128_aux (s:Seq.lseq UInt8.t 16) (ptr:int) (heap:S.heap) : Lemma
  (requires (forall (j:nat) . j < 16 ==> UInt8.v (Seq.index s j) == heap.[ptr+j]))
  (ensures Views.get128 s == Mkfour
    (S.get_heap_val32 ptr heap)
    (S.get_heap_val32 (ptr+4) heap)
    (S.get_heap_val32 (ptr+8) heap)
    (S.get_heap_val32 (ptr+12) heap)) =
  Opaque_s.reveal_opaque S.get_heap_val32_def;
  Opaque_s.reveal_opaque Views.get128_def;
  ()


let index128_get_heap_val128 h b heap i =
  let open FStar.Mul in
  let vb = BV.mk_buffer_view b uint128_view in
  let ptr = buffer_addr b h + 16 * i in
  let s = B.as_seq h.hs b in
  let addr = buffer_addr b h in
  BV.length_eq vb;
  BV.view_indexing vb i;
  BV.as_buffer_mk_buffer_view b uint128_view;
  BV.get_view_mk_buffer_view b uint128_view;
  BV.as_seq_sel h.hs vb i;
  BV.get_sel h.hs vb i;
  let sv = Seq.index (buffer_as_seq h b) i in
  let sl = Seq.slice s (i*16) (i*16+16) in
  assert (sv == Views.get128 sl);
  let aux (j:nat{j < 16}) : Lemma (UInt8.v (Seq.index sl j) == heap.[ptr+j]) =
    assert (UInt8.v (Seq.index s (i*16 + j)) == heap.[addr + (i*16+j)]);
    Seq.lemma_index_slice s (i*16) (i*16+16) j;
    assert (UInt8.v (Seq.index sl j) == heap.[addr+(i*16+j)]);
    index_mul_helper addr i 16 j;
    ()
  in Classical.forall_intro aux;
  index128_get_heap_val128_aux sl ptr heap;
  ()

let modifies_goal_directed s h1 h2 = modifies s h1 h2
let lemma_modifies_goal_directed s h1 h2 = ()

let buffer_length_buffer_as_seq #t h b = ()

val same_underlying_seq (#t:typ) (h1 h2:mem) (b:buffer t) : Lemma
  (requires Seq.equal (B.as_seq h1.hs b) (B.as_seq h2.hs b))
  (ensures Seq.equal (buffer_as_seq h1 b) (buffer_as_seq h2 b))

let same_underlying_seq #t h1 h2 b =
  let rec aux (i:nat{i <= buffer_length b}) : Lemma
    (requires (forall (j:nat{j < i}). Seq.index (buffer_as_seq h1 b) j == Seq.index (buffer_as_seq h2 b) j) /\
    (Seq.equal (B.as_seq h1.hs b) (B.as_seq h2.hs b)))
    (ensures (forall (j:nat{j < buffer_length b}). Seq.index (buffer_as_seq h1 b) j == Seq.index (buffer_as_seq h2 b) j))
    (decreases %[(buffer_length b) - i]) =
    if i = buffer_length b then ()
    else (
      let bv = BV.mk_buffer_view b (uint_view t) in
      BV.as_buffer_mk_buffer_view b (uint_view t);
      BV.get_view_mk_buffer_view b (uint_view t);
      BV.get_sel h1.hs bv i;
      BV.get_sel h2.hs bv i;
      BV.as_seq_sel h1.hs bv i;
      BV.as_seq_sel h2.hs bv i;
      aux (i+1)
    )
  in aux 0

let modifies_buffer_elim #t1 b p h h' =
  M.modifies_buffer_elim b p h.hs h'.hs;
  assert (Seq.equal (B.as_seq h.hs b) (B.as_seq h'.hs b));
  same_underlying_seq h h' b;
  assert (Seq.equal (buffer_as_seq h b) (buffer_as_seq h' b));
  ()

let modifies_buffer_addr #t b p h h' = ()
let modifies_buffer_readable #t b p h h' = ()

let loc_disjoint_none_r s = M.loc_disjoint_none_r s
let loc_disjoint_union_r s s1 s2 = M.loc_disjoint_union_r s s1 s2
let loc_includes_refl s = M.loc_includes_refl s
let loc_includes_trans s1 s2 s3 = M.loc_includes_trans s1 s2 s3
let loc_includes_union_r s s1 s2 = M.loc_includes_union_r s s1 s2
let loc_includes_union_l s1 s2 s = M.loc_includes_union_l s1 s2 s
let loc_includes_union_l_buffer #t s1 s2 b = M.loc_includes_union_l s1 s2 (loc_buffer b)
let loc_includes_none s = M.loc_includes_none s
let modifies_refl s h = M.modifies_refl s h.hs
let modifies_goal_directed_refl s h = M.modifies_refl s h.hs
let modifies_loc_includes s1 h h' s2 = M.modifies_loc_includes s1 h.hs h'.hs s2
let modifies_trans s12 h1 h2 s23 h3 = M.modifies_trans s12 h1.hs h2.hs s23 h3.hs

let modifies_goal_directed_trans s12 h1 h2 s13 h3 =
  modifies_trans s12 h1 h2 s13 h3;
  modifies_loc_includes s13 h1 h3 (loc_union s12 s13);
  ()

let modifies_goal_directed_trans2 s12 h1 h2 s13 h3 = modifies_goal_directed_trans s12 h1 h2 s13 h3

let default_of_typ (t:typ) : type_of_typ t =
  match t with
  | TBase TUInt8 -> 0
  | TBase TUInt16 -> 0
  | TBase TUInt32 -> 0
  | TBase TUInt64 -> 0
  | TBase TUInt128 -> Words_s.Mkfour #nat32 0 0 0 0

let buffer_read #t b i h =
  if i < 0 || i >= buffer_length b then default_of_typ t else
  Seq.index (buffer_as_seq h b) i

val seq_upd (#b:_)
            (h:HS.mem)
            (vb:BV.buffer b{BV.live h vb})
            (i:nat{i < BV.length vb})
            (x:b)
  : Lemma (Seq.equal
      (Seq.upd (BV.as_seq h vb) i x)
      (BV.as_seq (BV.upd h vb i x) vb))

let seq_upd #b h vb i x =
  let old_s = BV.as_seq h vb in
  let new_s = BV.as_seq (BV.upd h vb i x) vb in
  let upd_s = Seq.upd old_s i x in
  let rec aux (k:nat) : Lemma
    (requires (k <= Seq.length upd_s /\ (forall (j:nat). j < k ==> Seq.index upd_s j == Seq.index new_s j)))
    (ensures (forall (j:nat). j < Seq.length upd_s ==> Seq.index upd_s j == Seq.index new_s j))
    (decreases %[(Seq.length upd_s) - k]) =
    if k = Seq.length upd_s then ()
    else begin
      BV.sel_upd vb i k x h;
      BV.as_seq_sel h vb k;
      BV.as_seq_sel (BV.upd h vb i x) vb k;
      aux (k+1)
    end
  in aux 0;
  ()

let buffer_write #t b i v h =
 if i < 0 || i >= buffer_length b then h else
 begin
   let view = uint_view t in
   let bv = BV.mk_buffer_view b view in
   BV.as_buffer_mk_buffer_view b view;
   BV.upd_modifies h.hs bv i (v_of_typ t v);
   let hs' = BV.upd h.hs bv i (v_of_typ t v) in
   let h':mem = {h with hs = hs'} in
   seq_upd h.hs bv i (v_of_typ t v);
   assert (Seq.equal (buffer_as_seq h' b) (Seq.upd (buffer_as_seq h b) i v));
   h'
 end

val addr_in_ptr: (#t:typ) -> (addr:int) -> (ptr:buffer t) -> (h:mem) ->
  GTot (b:bool{ not b <==> (forall i. 0 <= i /\ i < buffer_length ptr ==>
    addr <> (buffer_addr ptr h) + (view_n t) `op_Multiply` i)})

// Checks if address addr corresponds to one of the elements of buffer ptr
let addr_in_ptr #t addr ptr h =
  let n = buffer_length ptr in
  let base = buffer_addr ptr h in
  let rec aux (i:nat) : Tot (b:bool{not b <==> (forall j. i <= j /\ j < n ==>
    addr <> base + (view_n t) `op_Multiply` j)})
    (decreases %[n-i]) =
    if i >= n then false
    else if addr = base + (view_n t) `op_Multiply` i then true
    else aux (i+1)
  in aux 0

let rec get_addr_in_ptr (t:typ) (n base addr:nat) (i:nat{exists j. i <= j /\ j < n /\ base + (view_n t) `op_Multiply` j == addr}) :
    GTot (j:nat{base + (view_n t) `op_Multiply` j == addr})
    (decreases %[n-i]) =
    if base + (view_n t) `op_Multiply` i = addr then i
    else if i >= n then i
    else get_addr_in_ptr t n base addr (i+1)

let valid_buffer (t:typ) (addr:int) (b:b8) (h:mem) : GTot bool = B.length b % (view_n t) = 0 && (addr_in_ptr #t addr b h)

let rec valid_mem_aux (t:typ) addr (ps:list b8) (h:mem) : GTot (b:bool{
  (not b) <==> (forall (x:buffer t). (List.memP x ps ==> not (valid_buffer t addr x h) ))})
  = match ps with
    | [] -> false
    | a::q -> if valid_buffer t addr a h then true else valid_mem_aux t addr q h

let valid_mem64 ptr h = valid_mem_aux (TBase TUInt64) ptr h.ptrs h

let rec load_mem_aux (t:typ) addr (ps:list b8) (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs }) :
  GTot (type_of_typ t) =
  match ps with
  | [] -> default_of_typ t
  | a::q ->
    if valid_buffer t addr a h then
    begin
      let a:buffer t = a in
      let base = buffer_addr a h in
      buffer_read a (get_addr_in_ptr t (buffer_length a) base addr 0) h
    end
    else load_mem_aux t addr q h

let load_mem64 ptr h =
  if not (valid_mem64 ptr h) then 0
  else load_mem_aux (TBase TUInt64) ptr h.ptrs h

let length_t_eq (t:typ) (b:buffer t) : Lemma (B.length b == buffer_length b `op_Multiply` (view_n t)) =
  BV.as_buffer_mk_buffer_view b (uint_view t);
  BV.get_view_mk_buffer_view b (uint_view t);
  BV.length_eq (BV.mk_buffer_view b (uint_view t))

let rec get_addr_ptr (t:typ) (ptr:int) (h:mem) (ps:list b8{valid_mem_aux t ptr ps h}) :
  GTot (b:buffer t{List.memP b ps /\ valid_buffer t ptr b h}) =
  match ps with
  // The list cannot be empty because of the mem predicate
  | a::q -> if valid_buffer t ptr a h then a else get_addr_ptr t ptr h q

#set-options "--z3rlimit 100"

let rec load_buffer_read (t:typ) (ptr:int) (h:mem)
  (ps:list b8{I.list_disjoint_or_eq ps /\ valid_mem_aux t ptr ps h /\
    (forall x. List.memP x ps ==> List.memP x h.ptrs)}) : Lemma
  (let b = get_addr_ptr t ptr h ps in
   length_t_eq t b;
   let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
   load_mem_aux t ptr ps h == buffer_read #t b i h) =
      match ps with
      | a::q ->
        if valid_buffer t ptr a h then () else load_buffer_read t ptr h q

let rec store_mem_aux (t:typ) addr (ps:list b8) (v:type_of_typ t) (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs }) :
  GTot (h1:mem{h.addrs == h1.addrs /\ h.ptrs == h1.ptrs }) =
  match ps with
  | [] -> h
  | a::q ->
    if valid_buffer t addr a h then
    begin
      let a:buffer t = a in
      let base = buffer_addr a h in
      buffer_write a (get_addr_in_ptr t (buffer_length a) base addr 0) v h
    end
    else store_mem_aux t addr q v h

let store_mem64 i v h =
  if not (valid_mem64 i h) then h
  else store_mem_aux (TBase TUInt64) i h.ptrs v h

let rec store_buffer_write (t:typ) (ptr:int) (v:type_of_typ t) (h:mem)
  (ps:list b8{I.list_disjoint_or_eq ps /\ valid_mem_aux t ptr ps h /\
    (forall x. List.memP x ps ==> List.memP x h.ptrs)}) : Lemma
  (let b = get_addr_ptr t ptr h ps in
   length_t_eq t b;
   let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
   store_mem_aux t ptr ps v h == buffer_write b i v h) =
      match ps with
      | a::q ->
        if valid_buffer t ptr a h then () else store_buffer_write t ptr v h q

let valid_mem128 ptr h = valid_mem_aux (TBase TUInt128) ptr h.ptrs h
let load_mem128 ptr h =
  if not (valid_mem128 ptr h) then (default_of_typ (TBase TUInt128))
  else load_mem_aux (TBase TUInt128) ptr h.ptrs h
let store_mem128 ptr v h =
  if not (valid_mem128 ptr h) then h
  else store_mem_aux (TBase TUInt128) ptr h.ptrs v h

let lemma_valid_mem64 b i h = ()

#set-options "--z3rlimit 20"

let lemma_load_mem64 b i h =
  let addr = buffer_addr b h + 8 `op_Multiply` i in
  lemma_valid_mem64 b i h;
  let rec aux (ps:list b8{I.list_disjoint_or_eq ps})
    (h0:mem{h == h0 /\ (forall x. List.memP x ps ==> List.memP x h0.ptrs)}) :
    Lemma (requires (List.memP b ps /\ i < buffer_length b) )
    (ensures (load_mem_aux (TBase TUInt64) addr ps h0 == buffer_read b i h0)) =
    match ps with
    | [] -> ()
    | a::q ->
      if valid_buffer (TBase TUInt64) addr a h0 then begin
        let a:buffer64 = a in
        BV.length_eq (BV.mk_buffer_view a uint64_view);
        BV.get_view_mk_buffer_view a uint64_view;
        BV.as_buffer_mk_buffer_view a uint64_view;
        BV.length_eq (BV.mk_buffer_view b uint64_view);
        BV.get_view_mk_buffer_view b uint64_view;
        BV.as_buffer_mk_buffer_view b uint64_view;

        assert (I.disjoint_or_eq a b);
        assert (a == b);
          ()
      end
      else begin
        assert (b =!= a);
          aux q h0
      end
  in aux h.ptrs h

let lemma_store_mem64 b i v h =
  let addr = buffer_addr b h + 8 `op_Multiply` i in
  lemma_valid_mem64 b i h;
  let rec aux (ps:list b8{I.list_disjoint_or_eq ps})
    (h0:mem{h == h0 /\ (forall x. List.memP x ps ==> List.memP x h0.ptrs)}) :
    Lemma (requires (List.memP b ps /\ i < buffer_length b) )
    (ensures (store_mem_aux (TBase TUInt64) addr ps v h0 == buffer_write b i v h0)) =
    match ps with
    | [] -> ()
    | a::q ->
      if valid_buffer (TBase TUInt64) addr a h0 then begin
        let a:buffer64 = a in
        BV.length_eq (BV.mk_buffer_view a uint64_view);
        BV.get_view_mk_buffer_view a uint64_view;
        BV.as_buffer_mk_buffer_view a uint64_view;
        BV.length_eq (BV.mk_buffer_view b uint64_view);
        BV.get_view_mk_buffer_view b uint64_view;
        BV.as_buffer_mk_buffer_view b uint64_view;

        assert (I.disjoint_or_eq a b);
        assert (a == b);
          ()
      end
      else begin
        assert (b =!= a);
          aux q h0
      end
  in aux h.ptrs h

let lemma_valid_mem128 b i h = ()

let lemma_load_mem128 b i h =
  let addr = buffer_addr b h + 16 `op_Multiply` i in
  lemma_valid_mem128 b i h;
  let rec aux (ps:list b8{I.list_disjoint_or_eq ps})
    (h0:mem{h == h0 /\ (forall x. List.memP x ps ==> List.memP x h0.ptrs)}) :
    Lemma (requires (List.memP b ps /\ i < buffer_length b) )
    (ensures (load_mem_aux (TBase TUInt128) addr ps h0 == buffer_read b i h0)) =
    match ps with
    | [] -> ()
    | a::q ->
      if valid_buffer (TBase TUInt128) addr a h0 then begin
        let a:buffer128 = a in
        BV.length_eq (BV.mk_buffer_view a uint128_view);
        BV.get_view_mk_buffer_view a uint128_view;
        BV.as_buffer_mk_buffer_view a uint128_view;
        BV.length_eq (BV.mk_buffer_view b uint128_view);
        BV.get_view_mk_buffer_view b uint128_view;
        BV.as_buffer_mk_buffer_view b uint128_view;

        assert (I.disjoint_or_eq a b);
        assert (a == b);
          ()
      end
      else begin
        assert (b =!= a);
          aux q h0
      end
  in aux h.ptrs h

let lemma_store_mem128 b i v h =
  let addr = buffer_addr b h + 16 `op_Multiply` i in
  lemma_valid_mem128 b i h;
  let rec aux (ps:list b8{I.list_disjoint_or_eq ps})
    (h0:mem{h == h0 /\ (forall x. List.memP x ps ==> List.memP x h0.ptrs)}) :
    Lemma (requires (List.memP b ps /\ i < buffer_length b) )
    (ensures (store_mem_aux (TBase TUInt128) addr ps v h0 == buffer_write b i v h0)) =
    match ps with
    | [] -> ()
    | a::q ->
      if valid_buffer (TBase TUInt128) addr a h0 then begin
        let a:buffer128 = a in
        BV.length_eq (BV.mk_buffer_view a uint128_view);
        BV.get_view_mk_buffer_view a uint128_view;
        BV.as_buffer_mk_buffer_view a uint128_view;
        BV.length_eq (BV.mk_buffer_view b uint128_view);
        BV.get_view_mk_buffer_view b uint128_view;
        BV.as_buffer_mk_buffer_view b uint128_view;

        assert (I.disjoint_or_eq a b);
        assert (a == b);
          ()
      end
      else begin
        assert (b =!= a);
          aux q h0
      end
  in aux h.ptrs h

let rec same_get_addr_ptr (t:typ)
                        (ptr:int)
                        (h:mem)
                        (ps:list b8{valid_mem_aux t ptr ps h})
                        (b:buffer t{List.memP b h.ptrs})
                        (i:nat{i < buffer_length b})
                        (v:(type_of_typ t)) : Lemma
  (let h1 = buffer_write b i v h in
  get_addr_ptr t ptr h ps == get_addr_ptr t ptr h1 ps) =
  match ps with
  | a::q -> if valid_buffer t ptr a h then () else same_get_addr_ptr t ptr h q b i v

let lemma_store_load_mem64 ptr v h =
  let t = TBase TUInt64 in
  let h1 = store_mem64 ptr v h in
  store_buffer_write t ptr v h h.ptrs;
  load_buffer_read t ptr h1 h1.ptrs;
  let b = get_addr_ptr t ptr h h.ptrs in
  length_t_eq t b;
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  same_get_addr_ptr t ptr h h.ptrs b i v;
  BV.as_buffer_mk_buffer_view b (uint_view t);
  BV.as_seq_sel h1.hs (BV.mk_buffer_view b (uint_view t)) i;
  ()

#set-options "--z3rlimit 50"

val different_addr_ptr64 (i:int) (i':nat{i <> i'})
                       (h:mem{valid_mem_aux (TBase TUInt64) i h.ptrs h /\ valid_mem_aux (TBase TUInt64) i' h.ptrs h}) : Lemma
  (let t = TBase TUInt64 in
  get_addr_ptr t i h h.ptrs =!= get_addr_ptr t i' h h.ptrs \/
    (let (b:buffer t) = get_addr_ptr t i h h.ptrs in
     let (b':buffer t) = get_addr_ptr t i' h h.ptrs in
     b == b' /\ get_addr_in_ptr t (buffer_length b) (buffer_addr b h) i 0 <>
      get_addr_in_ptr t (buffer_length b) (buffer_addr b h) i' 0))

let rec different_addr_in_ptr (t:typ) (n base:nat) (addr1 addr2:nat) (i:nat{
  (exists j. i <= j /\ j < n /\ base + (view_n t) `op_Multiply` j == addr1) /\
  (exists k. i <= k /\ k < n /\ base + (view_n t) `op_Multiply` k == addr2)}) : Lemma
  (requires addr1 <> addr2)
  (ensures get_addr_in_ptr t n base addr1 i <> get_addr_in_ptr t n base addr2 i)
  (decreases %[n-i]) =
   if (base + (view_n t) `op_Multiply` i = addr1) || (base + (view_n t) `op_Multiply` i = addr2) || i >= n then ()
   else different_addr_in_ptr t n base addr1 addr2 (i+1)

let different_addr_ptr64 i i' h =
  let t = TBase TUInt64 in
  let rec aux (ps:list b8{valid_mem_aux t i ps h /\ valid_mem_aux t i' ps h}) :
    Lemma (get_addr_ptr t i h ps =!= get_addr_ptr t i' h ps \/
    (let b = get_addr_ptr t i h ps in
     let b' = get_addr_ptr t i' h ps in
     b == b' /\ get_addr_in_ptr t (buffer_length b) (buffer_addr b h) i 0 <>
      get_addr_in_ptr t (buffer_length b) (buffer_addr b h) i' 0)) =
     match ps with
     | a::q -> if valid_buffer t i a h then begin
       if valid_buffer t i' a h then begin
         let a:buffer t = a in
         assert (get_addr_ptr t i h ps == a);
         assert (get_addr_ptr t i' h ps == a);
         length_t_eq t a;
         different_addr_in_ptr t (buffer_length a) (buffer_addr a h) i i' 0
       end
       else ()
       end else if valid_buffer t i' a h then ()
       else aux q
  in aux h.ptrs

let lemma_frame_store_mem64 ptr v h =
  let h1 = store_mem64 ptr v h in
  let t = TBase TUInt64 in
  let aux i' : Lemma
    (requires i' <> ptr /\ valid_mem64 ptr h /\ valid_mem64 i' h)
    (ensures load_mem64 i' h == load_mem64 i' h1) =
    store_buffer_write t ptr v h h.ptrs;
    load_buffer_read t i' h1 h1.ptrs;
    load_buffer_read t i' h h.ptrs;
    let b1 = get_addr_ptr t ptr h h.ptrs in
    let i1 = get_addr_in_ptr t (buffer_length b1) (buffer_addr b1 h) ptr 0 in
    let b2 = get_addr_ptr t i' h h.ptrs in
    let i2 = get_addr_in_ptr t (buffer_length b2) (buffer_addr b2 h) i' 0 in
    same_get_addr_ptr t i' h h.ptrs b1 i1 v;
    BV.as_buffer_mk_buffer_view b1 uint64_view;
    BV.upd_modifies h.hs (BV.mk_buffer_view b1 uint64_view) i1 (v_of_typ t v);
    assert (load_mem64 i' h == buffer_read b2 i2 h);
    assert (load_mem64 i' h1 == buffer_read b2 i2 h1);
    different_addr_ptr64 ptr i' h;
    let aux_diff_buf () : Lemma
      (requires b1 =!= b2)
      (ensures load_mem64 i' h == load_mem64 i' h1) =
      assert (I.disjoint_or_eq b1 b2);
      BV.as_seq_sel h.hs (BV.mk_buffer_view b2 uint64_view) i2;
      BV.as_seq_sel h1.hs (BV.mk_buffer_view b2 uint64_view) i2
    in let aux_same_buf () : Lemma
      (requires i1 <> i2 /\ b1 == b2)
      (ensures load_mem64 i' h == load_mem64 i' h1) =
      BV.sel_upd (BV.mk_buffer_view b2 uint64_view) i1 i2 (v_of_typ t v) h.hs
    in
    Classical.move_requires aux_diff_buf ();
    Classical.move_requires aux_same_buf ();
    ()
  in Classical.forall_intro (Classical.move_requires aux)

let lemma_valid_store_mem64 i v h = ()

let lemma_store_load_mem128 ptr v h =
  let t = TBase TUInt128 in
  let h1 = store_mem128 ptr v h in
  store_buffer_write t ptr v h h.ptrs;
  load_buffer_read t ptr h1 h1.ptrs;
  let b = get_addr_ptr t ptr h h.ptrs in
  length_t_eq t b;
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  same_get_addr_ptr t ptr h h.ptrs b i v;
  BV.as_buffer_mk_buffer_view b (uint_view t);
  BV.as_seq_sel h1.hs (BV.mk_buffer_view b (uint_view t)) i;
  ()

val different_addr_ptr128 (i:int) (i':nat{i <> i'})
                       (h:mem{valid_mem_aux (TBase TUInt128) i h.ptrs h /\ valid_mem_aux (TBase TUInt128) i' h.ptrs h}) : Lemma
  (let t = TBase TUInt128 in
  get_addr_ptr t i h h.ptrs =!= get_addr_ptr t i' h h.ptrs \/
    (let (b:buffer t) = get_addr_ptr t i h h.ptrs in
     let (b':buffer t) = get_addr_ptr t i' h h.ptrs in
     b == b' /\ get_addr_in_ptr t (buffer_length b) (buffer_addr b h) i 0 <>
      get_addr_in_ptr t (buffer_length b) (buffer_addr b h) i' 0))

let different_addr_ptr128 i i' h =
  let t = TBase TUInt128 in
  let rec aux (ps:list b8{valid_mem_aux t i ps h /\ valid_mem_aux t i' ps h}) :
    Lemma (get_addr_ptr t i h ps =!= get_addr_ptr t i' h ps \/
    (let b = get_addr_ptr t i h ps in
     let b' = get_addr_ptr t i' h ps in
     b == b' /\ get_addr_in_ptr t (buffer_length b) (buffer_addr b h) i 0 <>
      get_addr_in_ptr t (buffer_length b) (buffer_addr b h) i' 0)) =
     match ps with
     | a::q -> if valid_buffer t i a h then begin
       if valid_buffer t i' a h then begin
         let a:buffer t = a in
         assert (get_addr_ptr t i h ps == a);
         assert (get_addr_ptr t i' h ps == a);
         length_t_eq t a;
         different_addr_in_ptr t (buffer_length a) (buffer_addr a h) i i' 0
       end
       else ()
       end else if valid_buffer t i' a h then ()
       else aux q
  in aux h.ptrs

let lemma_frame_store_mem128 ptr v h =
  let h1 = store_mem128 ptr v h in
  let t = TBase TUInt128 in
  let aux i' : Lemma
    (requires i' <> ptr /\ valid_mem128 ptr h /\ valid_mem128 i' h)
    (ensures load_mem128 i' h == load_mem128 i' h1) =
    store_buffer_write t ptr v h h.ptrs;
    load_buffer_read t i' h1 h1.ptrs;
    load_buffer_read t i' h h.ptrs;
    let b1 = get_addr_ptr t ptr h h.ptrs in
    let i1 = get_addr_in_ptr t (buffer_length b1) (buffer_addr b1 h) ptr 0 in
    let b2 = get_addr_ptr t i' h h.ptrs in
    let i2 = get_addr_in_ptr t (buffer_length b2) (buffer_addr b2 h) i' 0 in
    same_get_addr_ptr t i' h h.ptrs b1 i1 v;
    BV.as_buffer_mk_buffer_view b1 uint128_view;
    BV.upd_modifies h.hs (BV.mk_buffer_view b1 uint128_view) i1 (v_of_typ t v);
    assert (load_mem128 i' h == buffer_read b2 i2 h);
    assert (load_mem128 i' h1 == buffer_read b2 i2 h1);
    different_addr_ptr128 ptr i' h;
    let aux_diff_buf () : Lemma
      (requires b1 =!= b2)
      (ensures load_mem128 i' h == load_mem128 i' h1) =
      assert (I.disjoint_or_eq b1 b2);
      BV.as_seq_sel h.hs (BV.mk_buffer_view b2 uint128_view) i2;
      BV.as_seq_sel h1.hs (BV.mk_buffer_view b2 uint128_view) i2
    in let aux_same_buf () : Lemma
      (requires i1 <> i2 /\ b1 == b2)
      (ensures load_mem128 i' h == load_mem128 i' h1) =
      BV.sel_upd (BV.mk_buffer_view b2 uint128_view) i1 i2 (v_of_typ t v) h.hs
    in
    Classical.move_requires aux_diff_buf ();
    Classical.move_requires aux_same_buf ();
    ()
  in Classical.forall_intro (Classical.move_requires aux)

let lemma_valid_store_mem128 ptr v h = ()

#set-options "--z3rlimit 100"

val heap_shift (m1 m2:S.heap) (base:int) (n:nat) : Lemma
  (requires (forall i. 0 <= i /\ i < n ==> m1.[base + i] == m2.[base + i]))
  (ensures (forall i. {:pattern (m1.[i])} base <= i /\ i < base + n ==> m1.[i] == m2.[i]))

let heap_shift m1 m2 base n =
  assert (forall i. base <= i /\ i < base + n ==>
    m1.[base + (i - base)] == m2.[base + (i - base)])

val same_mem_get_heap_val64 (b:buffer64)
                          (i:nat{i < buffer_length b})
                          (v:nat64)
                          (k:nat{k < buffer_length b})
                          (h1:mem{List.memP b h1.ptrs})
                          (h2:mem{h2 == buffer_write b i v h1})
                          (mem1:S.heap{I.correct_down_p h1.hs h1.addrs mem1 b})
                          (mem2:S.heap{I.correct_down_p h2.hs h2.addrs mem2 b}) : Lemma
  (requires (Seq.index (buffer_as_seq h1 b) k == Seq.index (buffer_as_seq h2 b) k))
  (ensures (let ptr = buffer_addr b h1 + 8 `op_Multiply` k in
    forall i. {:pattern (mem1.[ptr+i])} i >= 0 /\ i < 8 ==> mem1.[ptr+i] == mem2.[ptr+i]))

val same_mem_eq_slices64 (b:buffer64)
                       (i:nat{i < buffer_length b})
                       (v:nat64)
                       (k:nat{k < buffer_length b})
                       (h1:mem{List.memP b h1.ptrs})
                       (h2:mem{h2 == buffer_write b i v h1})
                       (mem1:S.heap{I.correct_down_p h1.hs h1.addrs mem1 b})
                       (mem2:S.heap{I.correct_down_p h2.hs h2.addrs mem2 b}) : Lemma
  (requires (Seq.index (buffer_as_seq h1 b) k == Seq.index (buffer_as_seq h2 b) k))
  (ensures (let open FStar.Mul in
    k * 8 + 8 <= B.length b /\
    Seq.slice (B.as_seq h1.hs b) (k * 8) (k * 8 + 8) ==
    Seq.slice (B.as_seq h2.hs b) (k * 8) (k * 8 + 8)))

let same_mem_eq_slices64 b i v k h1 h2 mem1 mem2 =
    let t = TBase TUInt64 in
    BV.as_seq_sel h1.hs (BV.mk_buffer_view b (uint_view t)) k;
    BV.as_seq_sel h2.hs (BV.mk_buffer_view b (uint_view t)) k;
    BV.put_sel h1.hs (BV.mk_buffer_view b (uint_view t)) k;
    BV.put_sel h2.hs (BV.mk_buffer_view b (uint_view t)) k;
    BV.as_buffer_mk_buffer_view b (uint_view t);
    BV.get_view_mk_buffer_view b (uint_view t);
    BV.view_indexing (BV.mk_buffer_view b (uint_view t)) k;
    BV.length_eq (BV.mk_buffer_view b (uint_view t))

#set-options "--z3rlimit 150"

let length_up64 (b:buffer64) (h:mem) (k:nat{k < buffer_length b}) (i:nat{i < 8}) : Lemma
  (8 `op_Multiply` k + i <= B.length b) =
  let vb = BV.mk_buffer_view b uint64_view in
  BV.length_eq vb;
  BV.as_buffer_mk_buffer_view b uint64_view;
  BV.get_view_mk_buffer_view b uint64_view;
  ()

let same_mem_get_heap_val64 b j v k h1 h2 mem1 mem2 =
  let ptr = buffer_addr b h1 + 8 `op_Multiply` k in
  let addr = buffer_addr b h1 in
  let aux (i:nat{i < 8}) : Lemma (mem1.[addr+(8 `op_Multiply` k + i)] == mem2.[addr+(8 `op_Multiply` k +i)]) =
    BV.as_seq_sel h1.hs (BV.mk_buffer_view b uint64_view) k;
    BV.as_seq_sel h2.hs (BV.mk_buffer_view b uint64_view) k;
    same_mem_eq_slices64 b j v k h1 h2 mem1 mem2;
    let open FStar.Mul in
    let s1 = (Seq.slice (B.as_seq h1.hs b) (k * 8) (k * 8 + 8)) in
    let s2 = (Seq.slice (B.as_seq h2.hs b) (k * 8) (k * 8 + 8)) in
    assert (Seq.index s1 i == Seq.index (B.as_seq h1.hs b) (k * 8 + i));
    length_up64 b h1 k i;
    assert (mem1.[addr+(8 * k + i)] == UInt8.v (Seq.index (B.as_seq h1.hs b) (k * 8 + i)));
    assert (Seq.index s2 i == Seq.index (B.as_seq h2.hs b) (k * 8 + i));
    length_up64 b h2 k i;
    assert (mem2.[addr+(8 * k + i)] == UInt8.v (Seq.index (B.as_seq h2.hs b) (k * 8 + i)));
    ()
  in
  Classical.forall_intro aux;
  assert (forall i. addr + (8 `op_Multiply` k + i) == ptr + i);
  ()

let rec written_buffer_down64_aux1 (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
      (ps:list b8{I.list_disjoint_or_eq ps /\ List.memP b ps})
      (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs})
      (base:nat{base == buffer_addr b h})
      (k:nat) (h1:mem{h1 == buffer_write b i v h})
      (mem1:S.heap{I.correct_down h.hs h.addrs ps mem1})
      (mem2:S.heap{
      (I.correct_down h1.hs h.addrs ps mem2) /\
      (forall j. base <= j /\ j < base + k `op_Multiply` 8 ==> mem1.[j] == mem2.[j])}) :
      Lemma (requires True)
      (ensures (forall j. j >= base /\ j < base + 8 `op_Multiply` i ==> mem1.[j] == mem2.[j]))
      (decreases %[i-k]) =
    if k >= i then ()
    else begin
      let ptr = base + 8 `op_Multiply` k in
      same_mem_get_heap_val64 b i v k h h1 mem1 mem2;
      heap_shift mem1 mem2 ptr 8;
      written_buffer_down64_aux1 b i v ps h base (k+1) h1 mem1 mem2
    end

let rec written_buffer_down64_aux2 (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
      (ps:list b8{I.list_disjoint_or_eq ps /\ List.memP b ps})
      (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs})
      (base:nat{base == buffer_addr b h})
      (n:nat{n == buffer_length b})
      (k:nat{k > i}) (h1:mem{h1 == buffer_write b i v h})
      (mem1:S.heap{I.correct_down h.hs h.addrs ps mem1})
      (mem2:S.heap{
      (I.correct_down h1.hs h.addrs ps mem2) /\
      (forall j. base + 8 `op_Multiply` (i+1) <= j /\ j < base + k `op_Multiply` 8 ==>
      mem1.[j] == mem2.[j])}) :
      Lemma
      (requires True)
      (ensures (forall j. j >= base + 8 `op_Multiply` (i+1) /\ j < base + 8 `op_Multiply` n ==>
        mem1.[j] == mem2.[j]))
      (decreases %[n-k]) =
    if k >= n then ()
    else begin
      let ptr = base + 8 `op_Multiply` k in
      same_mem_get_heap_val64 b i v k h h1 mem1 mem2;
      heap_shift mem1 mem2 ptr 8;
      written_buffer_down64_aux2 b i v ps h base n (k+1) h1 mem1 mem2
    end

let written_buffer_down64 (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
  (ps: list b8{I.list_disjoint_or_eq ps /\ List.memP b ps}) (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs}) :
  Lemma (
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    let n = buffer_length b in
    forall j. (base <= j /\ j < base + 8 `op_Multiply` i) \/
         (base + 8 `op_Multiply` (i+1) <= j /\ j < base + 8 `op_Multiply` n) ==>
         mem1.[j] == mem2.[j]) =
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    let n = buffer_length b in
    written_buffer_down64_aux1 b i v ps h base 0 h1 mem1 mem2;
    written_buffer_down64_aux2 b i v ps h base n (i+1) h1 mem1 mem2

#set-options "--z3rlimit 50"

let unwritten_buffer_down_aux (t:typ) (b:buffer t) (i:nat{i < buffer_length b}) (v:type_of_typ t)
  (ps: list b8{I.list_disjoint_or_eq ps /\ List.memP b ps})
  (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs})
  (a:b8{a =!= b /\ List.memP a ps})  :
  Lemma (let base = h.addrs a in
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    forall j. j >= base /\ j < base + B.length a ==> mem1.[j] == mem2.[j]) =
    if B.length a = 0 then ()
    else
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = h.addrs a in
    let s0 = B.as_seq h.hs a in
    let s1 = B.as_seq h1.hs a in
    assert (B.disjoint a b);
    heap_shift mem1 mem2 base (B.length a)

let unwritten_buffer_down (t:typ) (b:buffer t) (i:nat{i < buffer_length b}) (v:type_of_typ t)
  (ps: list b8{I.list_disjoint_or_eq ps /\ List.memP b ps})
  (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs}) : Lemma (
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    forall  (a:b8{List.memP a ps /\ a =!= b}) j.
    let base = h.addrs a in
    j >= base /\ j < base + B.length a ==> mem1.[j] == mem2.[j]) =
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let fintro (a:b8{List.memP a ps /\ a =!= b})
      : Lemma
      (forall j. let base = h.addrs a in
      j >= base /\ j < base + B.length a ==>
        mem1.[j] == mem2.[j]) =
      let base = h.addrs a in
      unwritten_buffer_down_aux t b i v ps h a
    in
    Classical.forall_intro fintro

let store_buffer_down64_mem (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
  (ps: list b8{I.list_disjoint_or_eq ps /\ List.memP b ps})
  (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs}) :
  Lemma (
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    forall (j:int). j < base + 8 `op_Multiply` i \/ j >= base + 8 `op_Multiply` (i+1) ==>
      mem1.[j] == mem2.[j]) =
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    let n = buffer_length b in
    let aux (j:int) : Lemma
      (j < base + 8 `op_Multiply` i \/ j >= base + 8 `op_Multiply` (i+1) ==>
      mem1.[j] == mem2.[j]) =
        if j >= base && j < base + B.length b then begin
          written_buffer_down64 b i v ps h;
          length_t_eq (TBase TUInt64) b
        end
        else (
        unwritten_buffer_down (TBase TUInt64) b i v ps h;
        I.same_unspecified_down h.hs h1.hs h.addrs ps;
        ()
        )
    in Classical.forall_intro aux

let store_buffer_aux_down64_mem (ptr:int) (v:nat64) (h:mem{valid_mem64 ptr h}) : Lemma (
  let mem1 = I.down_mem h.hs h.addrs h.ptrs in
  let h1 = store_mem_aux (TBase TUInt64) ptr h.ptrs v h in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  forall j. j < ptr \/ j >= ptr + 8 ==> mem1.[j] == mem2.[j]) =
  let t = TBase TUInt64 in
  let h1 = store_mem_aux t ptr h.ptrs v h in
  let b = get_addr_ptr t ptr h h.ptrs in
  length_t_eq t b;
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  store_buffer_write t ptr v h h.ptrs;
  assert (buffer_addr b h + 8 `op_Multiply` i == ptr);
  assert (buffer_addr b h + 8 `op_Multiply` (i+1) == ptr + 8);
  store_buffer_down64_mem b i v h.ptrs h

let store_buffer_aux_down64_mem2 (ptr:int) (v:nat64) (h:mem{valid_mem64 ptr h}) : Lemma (
  let h1 = store_mem_aux (TBase TUInt64) ptr h.ptrs v h in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  S.get_heap_val64 ptr mem2 == v) =
  let t = TBase TUInt64 in
  let b = get_addr_ptr t ptr h h.ptrs in
  length_t_eq t b;
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  let h1 = store_mem_aux t ptr h.ptrs v h in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  store_buffer_write t ptr v h h.ptrs;
  assert (Seq.index (buffer_as_seq h1 b) i == v);
  index64_get_heap_val64 h1 b mem2 i;
  ()

let in_bounds64 (h:mem) (b:buffer64) (i:nat{i < buffer_length b}) : Lemma
  (forall j. j >= h.addrs b + 8 `op_Multiply` i /\ j < h.addrs b + 8 `op_Multiply` i + 8 ==>
    j < h.addrs b + B.length b) =
  length_t_eq (TBase TUInt64) b;
  ()

val bytes_valid_aux: (ptr:int) -> (h:mem) -> Lemma
  (requires valid_mem64 ptr h)
  (ensures S.valid_addr64 ptr (get_heap h))

let bytes_valid_aux ptr h =
  let t = TBase TUInt64 in
  let b = get_addr_ptr t ptr h h.ptrs in
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  in_bounds64 h b i;
  I.addrs_set_mem h.ptrs b h.addrs ptr;
  I.addrs_set_mem h.ptrs b h.addrs (ptr+1);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+2);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+3);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+4);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+5);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+6);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+7);
  ()

let bytes_valid ptr s = bytes_valid_aux ptr s.mem

val valid_state_store_mem64_aux: (i:int) -> (v:nat64) -> (h:mem) -> Lemma 
  (requires valid_mem64 i h)
  (ensures (
    let heap = get_heap h in
    let heap' = S.update_heap64 i v heap in
    let h' = store_mem64 i v h in
    heap' == I.down_mem h'.hs h'.addrs h'.ptrs 
  ))

let valid_state_store_mem64_aux i v h =
  let heap = get_heap h in
  let heap' = S.update_heap64 i v heap in
  let h1 = store_mem_aux (TBase TUInt64) i h.ptrs v h in
  store_buffer_aux_down64_mem i v h;
  store_buffer_aux_down64_mem2 i v h;
  let mem1 = heap' in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  let aux () : Lemma (forall j. mem1.[j] == mem2.[j]) =
    Bytes_Semantics.same_mem_get_heap_val i mem1 mem2;
    Bytes_Semantics.correct_update_get i v heap;
    Bytes_Semantics.frame_update_heap i v heap
  in let aux2 () : Lemma (Set.equal (Map.domain mem1) (Map.domain mem2)) =
    bytes_valid_aux i h;
    Bytes_Semantics.same_domain_update i v heap
  in aux(); aux2();
  Map.lemma_equal_intro mem1 mem2;
  ()

let valid_state_store_mem64 i v (s:state) = 
  if not (valid_mem64 i s.mem) then ()
  else valid_state_store_mem64_aux i v s.mem
  
val same_mem_get_heap_val128 (b:buffer128)
                          (i:nat{i < buffer_length b})
                          (v:quad32)
                          (k:nat{k < buffer_length b})
                          (h1:mem{List.memP b h1.ptrs})
                          (h2:mem{h2 == buffer_write b i v h1})
                          (mem1:S.heap{I.correct_down_p h1.hs h1.addrs mem1 b})
                          (mem2:S.heap{I.correct_down_p h2.hs h2.addrs mem2 b}) : Lemma
  (requires (Seq.index (buffer_as_seq h1 b) k == Seq.index (buffer_as_seq h2 b) k))
  (ensures (let ptr = buffer_addr b h1 + 16 `op_Multiply` k in
    forall i. {:pattern (mem1.[ptr+i])} i >= 0 /\ i < 16 ==> mem1.[ptr+i] == mem2.[ptr+i]))

val same_mem_eq_slices128 (b:buffer128)
                       (i:nat{i < buffer_length b})
                       (v:quad32)
                       (k:nat{k < buffer_length b})
                       (h1:mem{List.memP b h1.ptrs})
                       (h2:mem{h2 == buffer_write b i v h1})
                       (mem1:S.heap{I.correct_down_p h1.hs h1.addrs mem1 b})
                       (mem2:S.heap{I.correct_down_p h2.hs h2.addrs mem2 b}) : Lemma
  (requires (Seq.index (buffer_as_seq h1 b) k == Seq.index (buffer_as_seq h2 b) k))
  (ensures (let open FStar.Mul in
    k * 16 + 16 <= B.length b /\
    Seq.slice (B.as_seq h1.hs b) (k * 16) (k * 16 + 16) ==
    Seq.slice (B.as_seq h2.hs b) (k * 16) (k * 16 + 16)))

let same_mem_eq_slices128 b i v k h1 h2 mem1 mem2 =
    let t = TBase TUInt128 in
    BV.as_seq_sel h1.hs (BV.mk_buffer_view b (uint_view t)) k;
    BV.as_seq_sel h2.hs (BV.mk_buffer_view b (uint_view t)) k;
    BV.put_sel h1.hs (BV.mk_buffer_view b (uint_view t)) k;
    BV.put_sel h2.hs (BV.mk_buffer_view b (uint_view t)) k;
    BV.as_buffer_mk_buffer_view b (uint_view t);
    BV.get_view_mk_buffer_view b (uint_view t);
    BV.view_indexing (BV.mk_buffer_view b (uint_view t)) k;
    BV.length_eq (BV.mk_buffer_view b (uint_view t))

let length_up128 (b:buffer128) (h:mem) (k:nat{k < buffer_length b}) (i:nat{i < 16}) : Lemma
  (16 `op_Multiply` k + i <= B.length b) =
  let vb = BV.mk_buffer_view b uint128_view in
  BV.length_eq vb;
  BV.as_buffer_mk_buffer_view b uint128_view;
  BV.get_view_mk_buffer_view b uint128_view;
  ()

let same_mem_get_heap_val128 b j v k h1 h2 mem1 mem2 =
  let ptr = buffer_addr b h1 + 16 `op_Multiply` k in
  let addr = buffer_addr b h1 in
  let aux (i:nat{i < 16}) : Lemma (mem1.[addr+(16 `op_Multiply` k + i)] == mem2.[addr+(16 `op_Multiply` k +i)]) =
    BV.as_seq_sel h1.hs (BV.mk_buffer_view b uint128_view) k;
    BV.as_seq_sel h2.hs (BV.mk_buffer_view b uint128_view) k;
    same_mem_eq_slices128 b j v k h1 h2 mem1 mem2;
    let open FStar.Mul in
    let s1 = (Seq.slice (B.as_seq h1.hs b) (k * 16) (k * 16 + 16)) in
    let s2 = (Seq.slice (B.as_seq h2.hs b) (k * 16) (k * 16 + 16)) in
    assert (Seq.index s1 i == Seq.index (B.as_seq h1.hs b) (k * 16 + i));
    length_up128 b h1 k i;
    assert (mem1.[addr+(16 * k + i)] == UInt8.v (Seq.index (B.as_seq h1.hs b) (k * 16 + i)));
    assert (Seq.index s2 i == Seq.index (B.as_seq h2.hs b) (k * 16 + i));
    length_up128 b h2 k i;
    assert (mem2.[addr+(16 * k + i)] == UInt8.v (Seq.index (B.as_seq h2.hs b) (k * 16 + i)));
    ()
  in
  Classical.forall_intro aux;
  assert (forall i. addr + (16 `op_Multiply` k + i) == ptr + i);
  ()

let rec written_buffer_down128_aux1 (b:buffer128) (i:nat{i < buffer_length b}) (v:quad32)
      (ps:list b8{I.list_disjoint_or_eq ps /\ List.memP b ps})
      (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs})
      (base:nat{base == buffer_addr b h})
      (k:nat) (h1:mem{h1 == buffer_write b i v h})
      (mem1:S.heap{I.correct_down h.hs h.addrs ps mem1})
      (mem2:S.heap{
      (I.correct_down h1.hs h.addrs ps mem2) /\
      (forall j. base <= j /\ j < base + k `op_Multiply` 16 ==> mem1.[j] == mem2.[j])}) :
      Lemma (requires True)
      (ensures (forall j. j >= base /\ j < base + 16 `op_Multiply` i ==> mem1.[j] == mem2.[j]))
      (decreases %[i-k]) =
    if k >= i then ()
    else begin
      let ptr = base + 16 `op_Multiply` k in
      same_mem_get_heap_val128 b i v k h h1 mem1 mem2;
      heap_shift mem1 mem2 ptr 16;
      written_buffer_down128_aux1 b i v ps h base (k+1) h1 mem1 mem2
    end

let rec written_buffer_down128_aux2 (b:buffer128) (i:nat{i < buffer_length b}) (v:quad32)
      (ps:list b8{I.list_disjoint_or_eq ps /\ List.memP b ps})
      (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs})
      (base:nat{base == buffer_addr b h})
      (n:nat{n == buffer_length b})
      (k:nat{k > i}) (h1:mem{h1 == buffer_write b i v h})
      (mem1:S.heap{I.correct_down h.hs h.addrs ps mem1})
      (mem2:S.heap{
      (I.correct_down h1.hs h.addrs ps mem2) /\
      (forall j. base + 16 `op_Multiply` (i+1) <= j /\ j < base + k `op_Multiply` 16 ==>
      mem1.[j] == mem2.[j])}) :
      Lemma
      (requires True)
      (ensures (forall j. j >= base + 16 `op_Multiply` (i+1) /\ j < base + 16 `op_Multiply` n ==>
        mem1.[j] == mem2.[j]))
      (decreases %[n-k]) =
    if k >= n then ()
    else begin
      let ptr = base + 16 `op_Multiply` k in
      same_mem_get_heap_val128 b i v k h h1 mem1 mem2;
      heap_shift mem1 mem2 ptr 16;
      written_buffer_down128_aux2 b i v ps h base n (k+1) h1 mem1 mem2
    end

let written_buffer_down128 (b:buffer128) (i:nat{i < buffer_length b}) (v:quad32)
  (ps: list b8{I.list_disjoint_or_eq ps /\ List.memP b ps}) (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs}) :
  Lemma (
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    let n = buffer_length b in
    forall j. (base <= j /\ j < base + 16 `op_Multiply` i) \/
         (base + 16 `op_Multiply` (i+1) <= j /\ j < base + 16 `op_Multiply` n) ==>
         mem1.[j] == mem2.[j]) =
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    let n = buffer_length b in
    written_buffer_down128_aux1 b i v ps h base 0 h1 mem1 mem2;
    written_buffer_down128_aux2 b i v ps h base n (i+1) h1 mem1 mem2

let store_buffer_down128_mem (b:buffer128) (i:nat{i < buffer_length b}) (v:quad32)
  (ps: list b8{I.list_disjoint_or_eq ps /\ List.memP b ps})
  (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs}) :
  Lemma (
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    forall j. j < base + 16 `op_Multiply` i \/ j >= base + 16 `op_Multiply` (i+1) ==>
      mem1.[j] == mem2.[j]) =
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    let n = buffer_length b in
    let aux (j:int) : Lemma
      (j < base + 16 `op_Multiply` i \/ j >= base + 16 `op_Multiply` (i+1) ==>
      mem1.[j] == mem2.[j]) =
        if j >= base && j < base + B.length b then begin
          written_buffer_down128 b i v ps h;
          length_t_eq (TBase TUInt128) b
        end
        else (
        I.same_unspecified_down h.hs h1.hs h.addrs ps;
        unwritten_buffer_down (TBase TUInt128) b i v ps h;
        ()
        )
    in Classical.forall_intro aux

let store_buffer_aux_down128_mem (ptr:int) (v:quad32) (h:mem{valid_mem128 ptr h}) : Lemma (
  let mem1 = I.down_mem h.hs h.addrs h.ptrs in
  let h1 = store_mem_aux (TBase TUInt128) ptr h.ptrs v h in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  forall j. j < ptr \/ j >= ptr + 16 ==> mem1.[j] == mem2.[j]) =
  let t = TBase TUInt128 in
  let h1 = store_mem_aux t ptr h.ptrs v h in
  let b = get_addr_ptr t ptr h h.ptrs in
  length_t_eq t b;
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  store_buffer_write t ptr v h h.ptrs;
  assert (buffer_addr b h + 16 `op_Multiply` i == ptr);
  assert (buffer_addr b h + 16 `op_Multiply` (i+1) == ptr + 16);
  store_buffer_down128_mem b i v h.ptrs h

let store_buffer_aux_down128_mem2 (ptr:int) (v:quad32) (h:mem{valid_mem128 ptr h}) : Lemma (
  let h1 = store_mem_aux (TBase TUInt128) ptr h.ptrs v h in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  Mkfour
    (S.get_heap_val32 ptr mem2)
    (S.get_heap_val32 (ptr+4) mem2)
    (S.get_heap_val32 (ptr+8) mem2)
    (S.get_heap_val32 (ptr+12) mem2)
  == v) =
  let t = TBase TUInt128 in
  let b = get_addr_ptr t ptr h h.ptrs in
  length_t_eq t b;
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  let h1 = store_mem_aux t ptr h.ptrs v h in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  store_buffer_write t ptr v h h.ptrs;
  assert (Seq.index (buffer_as_seq h1 b) i == v);
  index128_get_heap_val128 h1 b mem2 i;
  ()

let in_bounds128 (h:mem) (b:buffer128) (i:nat{i < buffer_length b}) : Lemma
  (forall j. j >= h.addrs b + 16 `op_Multiply` i /\ j < h.addrs b + 16 `op_Multiply` i + 16 ==>
    j < h.addrs b + B.length b) =
  length_t_eq (TBase TUInt128) b;
  ()

val bytes_valid128_aux: (ptr:int) -> (h:mem) -> Lemma
  (requires valid_mem128 ptr h)
  (ensures S.valid_addr128 ptr (get_heap h))

let bytes_valid128_aux ptr h =
  let t = TBase TUInt128 in
  let b = get_addr_ptr t ptr h h.ptrs in
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  in_bounds128 h b i;
  I.addrs_set_mem h.ptrs b h.addrs ptr;
  I.addrs_set_mem h.ptrs b h.addrs (ptr+1);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+2);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+3);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+4);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+5);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+6);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+7);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+8);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+9);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+10);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+11);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+12);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+13);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+14);
  I.addrs_set_mem h.ptrs b h.addrs (ptr+15);
  ()

let bytes_valid128 ptr s = bytes_valid128_aux ptr s.mem

val valid_state_store_mem128_aux: (i:int) -> (v:quad32) -> (h:mem) -> Lemma 
  (requires valid_mem128 i h)
  (ensures (
    let heap = get_heap h in
    let heap' = S.update_heap128 i v heap in
    let h' = store_mem128 i v h in
    heap' == I.down_mem h'.hs h'.addrs h'.ptrs 
  ))

let valid_state_store_mem128_aux i v h =
  let heap = get_heap h in
  let heap' = S.update_heap128 i v heap in
  let h1 = store_mem_aux (TBase TUInt128) i h.ptrs v h in
  store_buffer_aux_down128_mem i v h;
  store_buffer_aux_down128_mem2 i v h;
  let mem1 = heap' in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  let aux () : Lemma (forall j. mem1.[j] == mem2.[j]) =
    Bytes_Semantics.correct_update_get128 i v heap;
    Opaque_s.reveal_opaque Bytes_Semantics_s.get_heap_val128_def;
    Bytes_Semantics.same_mem_get_heap_val32 i mem1 mem2;
    Bytes_Semantics.same_mem_get_heap_val32 (i+4) mem1 mem2;
    Bytes_Semantics.same_mem_get_heap_val32 (i+8) mem1 mem2;
    Bytes_Semantics.same_mem_get_heap_val32 (i+12) mem1 mem2;
    Bytes_Semantics.frame_update_heap128 i v heap
  in
  let aux2 () : Lemma (Set.equal (Map.domain mem1) (Map.domain mem2)) =
    bytes_valid128_aux i h;
    Bytes_Semantics.same_domain_update128 i v heap
  in aux (); aux2 ();
  Map.lemma_equal_intro mem1 mem2

let valid_state_store_mem128 i v (s:state) =
  if not (valid_mem128 i s.mem) then ()
  else valid_state_store_mem128_aux i v s.mem

val equiv_load_mem_aux: (ptr:int) -> (h:mem) -> Lemma
  (requires valid_mem64 ptr h)
  (ensures load_mem64 ptr h == S.get_heap_val64 ptr (get_heap h))

let equiv_load_mem_aux ptr h =
  let t = TBase TUInt64 in
  let b = get_addr_ptr t ptr h h.ptrs in
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  let addr = buffer_addr b h in
  let contents = B.as_seq h.hs b in
  let heap = get_heap h in
  index64_get_heap_val64 h b heap i;
  lemma_load_mem64 b i h

let equiv_load_mem ptr s = equiv_load_mem_aux ptr s.mem

val equiv_load_mem128_aux: (ptr:int) -> (h:mem) -> Lemma
  (requires valid_mem128 ptr h)
  (ensures load_mem128 ptr h == S.get_heap_val128 ptr (get_heap h))

let equiv_load_mem128_aux ptr h =
  let t = TBase TUInt128 in
  let b = get_addr_ptr t ptr h h.ptrs in
  let i = get_addr_in_ptr t (buffer_length b) (buffer_addr b h) ptr 0 in
  let addr = buffer_addr b h in
  let contents = B.as_seq h.hs b in
  let heap = get_heap h in
  Opaque_s.reveal_opaque S.get_heap_val128_def;
  index128_get_heap_val128 h b heap i;
  lemma_load_mem128 b i h

let equiv_load_mem128 ptr s = equiv_load_mem128_aux ptr s.mem

let low_lemma_valid_mem64 b i h = 
  lemma_valid_mem64 b i h;
  bytes_valid_aux (buffer_addr b h + 8 `op_Multiply` i) h

let low_lemma_load_mem64 b i h =
  lemma_valid_mem64 b i h;
  lemma_load_mem64 b i h;
  equiv_load_mem_aux (buffer_addr b h + 8 `op_Multiply` i) h

let same_domain_update64 b i v h =
  low_lemma_valid_mem64 b i h;
  X64.Bytes_Semantics.same_domain_update (buffer_addr b h + 8 `op_Multiply` i) v (get_heap h)

open X64.BufferViewStore

let low_lemma_store_mem64_aux 
  (b:buffer64)
  (heap:S.heap)
  (i:nat{i < buffer_length b})
  (v:nat64)
  (h:mem{buffer_readable h b})
  : Lemma
    (requires I.correct_down_p h.hs h.addrs heap b)
    (ensures (let heap' = S.update_heap64 (buffer_addr b h + 8 `op_Multiply` i) v heap in
     let h' = store_mem64 (buffer_addr b h + 8 `op_Multiply` i) v h in
     h'.hs == B.g_upd_seq b (I.get_seq_heap heap' h.addrs b) h.hs)) =
   let ptr = buffer_addr b h + 8 `op_Multiply` i in
   let heap' = S.update_heap64 ptr v heap in
   let h' = store_mem64 ptr v h in
   length_t_eq (TBase TUInt64) b;
   store_buffer_write (TBase TUInt64) ptr v h h.ptrs;
   let b' = get_addr_ptr (TBase TUInt64) ptr h h.ptrs in
   assert (I.disjoint_or_eq b b');
   length_t_eq (TBase TUInt64) b';
   bv_upd_update_heap64 b heap i v h.addrs h.ptrs h.hs

let low_lemma_store_mem64 b i v h =
  lemma_valid_mem64 b i h;
  lemma_store_mem64 b i v h;
  valid_state_store_mem64_aux (buffer_addr b h + 8 `op_Multiply` i) v h;
  let heap = get_heap h in
  let heap' = S.update_heap64 (buffer_addr b h + 8 `op_Multiply` i) v heap in
  let h' = store_mem64 (buffer_addr b h + 8 `op_Multiply` i) v h in
  low_lemma_store_mem64_aux b heap i v h;
  length_t_eq (TBase TUInt64) b;
  X64.Bytes_Semantics.frame_update_heap (buffer_addr b h + 8 `op_Multiply` i) v heap;
  I.update_buffer_up_mem h.ptrs h.addrs h.hs b heap heap'  

let low_lemma_valid_mem128 b i h =
  lemma_valid_mem128 b i h;
  bytes_valid128_aux (buffer_addr b h + 16 `op_Multiply` i) h

let low_lemma_load_mem128 b i h =
  lemma_valid_mem128 b i h;
  lemma_load_mem128 b i h;
  equiv_load_mem128_aux (buffer_addr b h + 16 `op_Multiply` i) h  

let same_domain_update128 b i v h =
  low_lemma_valid_mem128 b i h;
  X64.Bytes_Semantics.same_domain_update128 (buffer_addr b h + 16 `op_Multiply` i) v (get_heap h)

let low_lemma_store_mem128_aux 
  (b:buffer128)
  (heap:S.heap)
  (i:nat{i < buffer_length b})
  (v:quad32)
  (h:mem{buffer_readable h b})
  : Lemma
    (requires I.correct_down_p h.hs h.addrs heap b)
    (ensures (let heap' = S.update_heap128 (buffer_addr b h + 16 `op_Multiply` i) v heap in
     let h' = store_mem128 (buffer_addr b h + 16 `op_Multiply` i) v h in
     h'.hs == B.g_upd_seq b (I.get_seq_heap heap' h.addrs b) h.hs)) =
   let ptr = buffer_addr b h + 16 `op_Multiply` i in
   let heap' = S.update_heap128 ptr v heap in
   let h' = store_mem128 ptr v h in
   length_t_eq (TBase TUInt128) b;
   store_buffer_write (TBase TUInt128) ptr v h h.ptrs;
   let b' = get_addr_ptr (TBase TUInt128) ptr h h.ptrs in
   assert (I.disjoint_or_eq b b');
   length_t_eq (TBase TUInt128) b';
   bv_upd_update_heap128 b heap i v h.addrs h.ptrs h.hs

let low_lemma_store_mem128 b i v h =
  lemma_valid_mem128 b i h;
  lemma_store_mem128 b i v h;
  valid_state_store_mem128_aux (buffer_addr b h + 16 `op_Multiply` i) v h;
  let heap = get_heap h in
  let heap' = S.update_heap128 (buffer_addr b h + 16 `op_Multiply` i) v heap in
  let h' = store_mem128 (buffer_addr b h + 16 `op_Multiply` i) v h in
  low_lemma_store_mem128_aux b heap i v h;  
  length_t_eq (TBase TUInt128) b;
  X64.Bytes_Semantics.frame_update_heap128 (buffer_addr b h + 16 `op_Multiply` i) v heap;
  I.update_buffer_up_mem h.ptrs h.addrs h.hs b heap heap'

let valid128_64 ptr h =
  let b = get_addr_ptr (TBase TUInt128) ptr h h.ptrs in
  let i = get_addr_in_ptr (TBase TUInt128) (buffer_length b) (buffer_addr b h) ptr 0 in
  let b:b8 = b in
  length_t_eq (TBase TUInt128) b;
  Math.Lemmas.Int.mod_mult_exact (B.length b) 8 2;
  length_t_eq (TBase TUInt64) b;
  lemma_valid_mem64 b (2 `op_Multiply` i) h;
  lemma_valid_mem64 b (2 `op_Multiply` i + 1) h;
  FStar.Math.Lemmas.paren_mul_right 8 2 i;
  FStar.Math.Lemmas.distributivity_add_right 8 (2 `op_Multiply` i) 1;
  FStar.Math.Lemmas.paren_add_right (h.addrs b) (8 `op_Multiply` (2 `op_Multiply` i)) 8

open Views

private
let load128_64_aux (s:Seq.lseq SecretByte.t 16) : Lemma
  (let v = get128 s in
   let v_lo = get64 (Seq.slice s 0 8) in
   let v_hi = get64 (Seq.slice s 8 16) in
   v.lo0 + 0x100000000 `op_Multiply` v.lo1 == UInt64.v v_lo /\
   v.hi2 + 0x100000000 `op_Multiply` v.hi3 == UInt64.v v_hi) = 
   Opaque_s.reveal_opaque get128_def;
   Opaque_s.reveal_opaque get64_def;
   ()

let buffer_read_get128 (b:buffer128) (i:nat{i < buffer_length b}) (h:mem) : Lemma
  (length_t_eq (TBase TUInt128) b;
  buffer_read b i h ==
    get128 (Seq.slice (B.as_seq h.hs b) (16 `op_Multiply` i) (16 `op_Multiply` i + 16))) =
  length_t_eq (TBase TUInt128) b;
  let vb = BV.mk_buffer_view b uint128_view in
  BV.as_buffer_mk_buffer_view b uint128_view;
  BV.get_view_mk_buffer_view b uint128_view;
  BV.get_sel h.hs vb i;
  BV.as_seq_sel h.hs vb i;
  ()

let buffer_read_get64_1 (b:buffer64) (i:nat{2 `op_Multiply` i < buffer_length b}) (h:mem) : Lemma
  (requires 16 `op_Multiply` i + 16 <= B.length b)
  (ensures (length_t_eq (TBase TUInt64) b;
  buffer_read b (2 `op_Multiply` i) h ==
    UInt64.v (get64 (Seq.slice (Seq.slice (B.as_seq h.hs b) (16 `op_Multiply` i) (16 `op_Multiply` i + 16)) 0 8)))) =
  length_t_eq (TBase TUInt64) b;
  let j = 2 `op_Multiply` i in
  let vb = BV.mk_buffer_view b uint64_view in
  BV.as_buffer_mk_buffer_view b uint64_view;
  BV.get_view_mk_buffer_view b uint64_view;
  BV.get_sel h.hs vb j;
  BV.as_seq_sel h.hs vb j;
  ()

let buffer_read_get64_2 (b:buffer64) (i:nat{2 `op_Multiply` i + 1 < buffer_length b}) (h:mem) : Lemma
  (requires 16 `op_Multiply` i + 16 <= B.length b)
  (ensures (length_t_eq (TBase TUInt64) b;
  buffer_read b (2 `op_Multiply` i + 1) h ==
    UInt64.v (get64 (Seq.slice (Seq.slice (B.as_seq h.hs b) (16 `op_Multiply` i) (16 `op_Multiply` i + 16)) 8 16)))) =
  length_t_eq (TBase TUInt64) b;
  let j = 2 `op_Multiply` i + 1 in
  let vb = BV.mk_buffer_view b uint64_view in
  BV.as_buffer_mk_buffer_view b uint64_view;
  BV.get_view_mk_buffer_view b uint64_view;
  BV.get_sel h.hs vb j;
  BV.as_seq_sel h.hs vb j;
  ()

let load128_math1 (i64 i128 base ptr:nat) : Lemma
  (requires (base + 8 `op_Multiply` i64 == base + 16 `op_Multiply` i128))
  (ensures (i64 == 2 `op_Multiply` i128)) = ()

let load128_math2 (i64 i128 base ptr:nat) : Lemma
  (requires (base + 8 `op_Multiply` i64 == base + 16 `op_Multiply` i128 + 8))
  (ensures (i64 == 2 `op_Multiply` i128 + 1)) = ()

let load128_64_same_buffers (ptr:int) (h:mem) : Lemma
  (requires (valid_mem128 ptr h))
  (ensures (
    valid128_64 ptr h;
    let b64_1 = get_addr_ptr (TBase TUInt64) ptr h h.ptrs in
    let b64_2 = get_addr_ptr (TBase TUInt64) (ptr+8) h h.ptrs in
    let b128 =  get_addr_ptr (TBase TUInt128) ptr h h.ptrs in
    b64_1 == b128 /\ b64_2 == b128)) =
  valid128_64 ptr h;
  let b64_1 = get_addr_ptr (TBase TUInt64) ptr h h.ptrs in
  let b64_2 = get_addr_ptr (TBase TUInt64) (ptr+8) h h.ptrs in
  let b128 =  get_addr_ptr (TBase TUInt128) ptr h h.ptrs in    
  load_buffer_read (TBase TUInt64) ptr h h.ptrs;
  load_buffer_read (TBase TUInt64) (ptr+8) h h.ptrs;
  load_buffer_read (TBase TUInt128) ptr h h.ptrs;  
  assert (Interop.disjoint_or_eq b64_1 b128);
  assert (Interop.disjoint_or_eq b64_2 b128);
  length_t_eq (TBase TUInt64) b64_1;
  length_t_eq (TBase TUInt64) b64_2;
  length_t_eq (TBase TUInt128) b128

let load128_64 ptr h =
  let v = load_mem128 ptr h in
  let v_lo = load_mem64 ptr h in
  let v_hi = load_mem64 (ptr+8) h in
  valid128_64 ptr h;
  load_buffer_read (TBase TUInt64) ptr h h.ptrs;
  load_buffer_read (TBase TUInt64) (ptr+8) h h.ptrs;
  load_buffer_read (TBase TUInt128) ptr h h.ptrs;
  let b64_1 = get_addr_ptr (TBase TUInt64) ptr h h.ptrs in
  let i64_1 = get_addr_in_ptr (TBase TUInt64) (buffer_length b64_1) (buffer_addr b64_1 h) ptr 0 in
  let b64_2 = get_addr_ptr (TBase TUInt64) (ptr+8) h h.ptrs in
  let i64_2 = get_addr_in_ptr (TBase TUInt64) (buffer_length b64_2) (buffer_addr b64_2 h) (ptr+8) 0 in
  let b128 = get_addr_ptr (TBase TUInt128) ptr h h.ptrs in
  let i128 = get_addr_in_ptr (TBase TUInt128) (buffer_length b128) (buffer_addr b128 h) ptr 0 in
  // The three buffers are actually the same since they overlap
  load128_64_same_buffers ptr h;
  length_t_eq (TBase TUInt64) b64_1;
  length_t_eq (TBase TUInt64) b64_2;
  length_t_eq (TBase TUInt128) b128;
  // Simplify the context to prove i64_1 = 2 * i128 and i64_2 = 2 * i128 + 1
  load128_math1 i64_1 i128 (buffer_addr b128 h) ptr;
  load128_math2 i64_2 i128 (buffer_addr b128 h) ptr;
  let s = B.as_seq h.hs b128 in
  let s = Seq.slice s (16 `op_Multiply` i128) (16 `op_Multiply` i128 + 16) in
  load128_64_aux s;
  buffer_read_get128 b128 i128 h;
  buffer_read_get64_1 b64_1 i128 h;
  buffer_read_get64_2 b64_2 i128 h;
  ()

let store128_64_valid ptr v s = ()

private
let store128_addr_in_ptr (t:typ) (ptr i:int) (v:quad32)
  (h:mem{valid_mem_aux t ptr h.ptrs h /\ valid_mem_aux t i h.ptrs h}) : Lemma 
   (let h' = store_mem128 ptr v h in
    (get_addr_ptr t i h h.ptrs == get_addr_ptr t i h' h'.ptrs)) =
  let h' = store_mem128 ptr v h in
  let rec aux (ps:list b8{valid_mem_aux t i ps h}) : Lemma
    (get_addr_ptr t i h ps == get_addr_ptr t i h' ps) =
  match ps with
    | a::q -> if valid_buffer t i a h then () else aux q
  in
  aux h.ptrs

open BufferViewHelpers

let store128_64_frame_aux (b128:buffer128) (b64:buffer64) 
  (i:nat{i < buffer_length b128}) 
  (j:nat{j < buffer_length b64}) 
  (h h':mem) : Lemma
  (requires buffer_read b128 i h == buffer_read b128 i h' /\ b128 == b64 /\ i = j/2)
  (ensures buffer_read b64 j h == buffer_read b64 j h') =
  length_t_eq (TBase TUInt128) b128;
  buffer_read_get128 b128 i h;
  buffer_read_get128 b128 i h';
  if j % 2 = 0 then begin
    buffer_read_get64_1 b64 i h;    
    buffer_read_get64_1 b64 i h'
  end
  else begin
    buffer_read_get64_2 b64 i h;    
    buffer_read_get64_2 b64 i h'
  end

let store128_64_math1 (base i i128 j ptr:int) : Lemma
  (requires base + 16 `op_Multiply` i128 == ptr /\ base + 8 `op_Multiply` j == i /\ i <> ptr /\ i <> ptr + 8)
  (ensures i128 <> j/2) = ()

let store128_64_math2 (b128:buffer128) (b64:buffer64) (j:nat) : Lemma
  (requires b128 == b64 /\ j < buffer_length b64)
  (ensures j/2 < buffer_length b128) =
  length_t_eq (TBase TUInt64) b64;
  length_t_eq (TBase TUInt128) b128

let store128_64_frame ptr v s =
  let h = s.mem in
  let h' = store_mem128 ptr v h in
  valid128_64 ptr h;
  let b128 = get_addr_ptr (TBase TUInt128) ptr h h.ptrs in
  let i128 = get_addr_in_ptr (TBase TUInt128) (buffer_length b128) (buffer_addr b128 h) ptr 0 in
  store_buffer_write (TBase TUInt128) ptr v h h.ptrs;
  assert (B.modifies (B.loc_buffer b128) h.hs h'.hs);
  let aux (i:int) : Lemma
    (requires i <> ptr /\ i <> ptr+8 /\ valid_mem64 i h)
    (ensures load_mem64 i h == load_mem64 i h') =
    load_buffer_read (TBase TUInt64) i h h.ptrs;
    load_buffer_read (TBase TUInt64) i h' h'.ptrs;
    let b = get_addr_ptr (TBase TUInt64) i h h.ptrs in
    let j = get_addr_in_ptr (TBase TUInt64) (buffer_length b) (buffer_addr b h) i 0 in
    store128_addr_in_ptr (TBase TUInt64) ptr i v h;
    assert (Interop.disjoint_or_eq b b128);
    if StrongExcludedMiddle.strong_excluded_middle (b =!= b128) then begin
      assert (Seq.equal (buffer_as_seq h b) (buffer_as_seq h' b));
      ()
    end
    else begin
      let i' = j/2 in
      let base = buffer_addr b h in
      // Make this an auxiliary lemma to simplify context
      store128_64_math1 base i i128 j ptr;
      store128_64_math2 b128 b j;
      store128_64_frame_aux b128 b i' j h h'
    end
  in Classical.forall_intro (Classical.move_requires aux)


let store128_64_load ptr v s =
  let h = store_mem128 ptr v s.mem in
  lemma_store_load_mem128 ptr v s.mem;
  load128_64 ptr h


open X64.Machine_s

let valid_taint_buf (b:b8) (mem:mem) (memTaint:memtaint) t =
  let addr = mem.addrs b in
  (forall (i:nat{i < B.length b}). memTaint.[addr + i] = t)

let valid_taint_buf64 b mem memTaint t = valid_taint_buf b mem memTaint t

let valid_taint_buf128 b mem memTaint t = valid_taint_buf b mem memTaint t

let lemma_valid_taint64 b memTaint mem i t =
  length_t_eq (TBase TUInt64) b;
  ()

let lemma_valid_taint128 b memTaint mem i t =
  length_t_eq (TBase TUInt128) b;
  assert (memTaint.[(buffer_addr b mem + (16 `op_Multiply` i + 8))] == t);
  ()

let same_memTaint (t:typ) (b:buffer t) (mem0 mem1:mem) (memT0 memT1:memtaint) : Lemma
  (requires modifies (loc_buffer b) mem0 mem1 /\
    (forall p. Map.sel memT0 p == Map.sel memT1 p))
  (ensures memT0 == memT1) =
  assert (Map.equal memT0 memT1);
  ()


let same_memTaint64 b mem0 mem1 memtaint0 memtaint1 =
same_memTaint (TBase TUInt64) b mem0 mem1 memtaint0 memtaint1

let same_memTaint128 b mem0 mem1 memtaint0 memtaint1 =
  same_memTaint (TBase TUInt128) b mem0 mem1 memtaint0 memtaint1

let modifies_valid_taint64 b p h h' memTaint t = ()
let modifies_valid_taint128 b p h h' memTaint t = ()

let valid_taint_bufs (mem:mem) (memTaint:memtaint) (ps:list b8) (ts:b8 -> GTot taint) =
  forall b. List.memP b ps ==> valid_taint_buf b mem memTaint (ts b)

val create_valid_memtaint
  (mem:mem)
  (ps:list b8{I.list_disjoint_or_eq ps})
  (ts:b8 -> GTot taint) :
  GTot (m:memtaint{valid_taint_bufs mem m ps ts})

private
let rec write_taint (t:taint) (length addr:nat) (i:nat{i <= length}) (accu:memtaint{
  forall j. 0 <= j /\ j < i ==> accu.[addr+j] = t}) : Tot (m:memtaint{
  forall j. (0 <= j /\ j < length ==> m.[addr+j] = t) /\
       (j < addr \/ j >= addr + length ==> m.[j] == accu.[j])})
  (decreases %[length - i]) =
  if i >= length then accu
  else (
    let new_accu = accu.[addr+i] <- t in
    assert (Set.equal (Map.domain new_accu) (Set.complement Set.empty));
    write_taint t length addr (i+1) new_accu
  )

let create_valid_memtaint mem ps ts =
  let memTaint = FStar.Map.const Public in
  assert (Set.equal (Map.domain memTaint) (Set.complement Set.empty));
  let rec aux (ps:list b8{I.list_disjoint_or_eq ps}) (accu:memtaint) : GTot (m:memtaint{valid_taint_bufs mem m ps ts /\ (forall j. (forall b. List.memP b ps ==> j < mem.addrs b \/ j >= mem.addrs b + B.length b) ==> accu.[j] = m.[j])}) =
  match ps with
    | [] -> accu
    | b::q ->
    let accu = aux q (write_taint (ts b) (B.length b) (mem.addrs b) 0 accu) in
    assert (forall p. List.memP p q ==> I.disjoint_or_eq p b);
    accu
  in aux ps memTaint
